import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_item.dart';
import '../models/hymn.dart';
import '../models/recording.dart';

/// Downloads recordings, remembers which ones are fully saved, and tells
/// the screens about progress. A recording only counts as downloaded after
/// the whole file has arrived and been checked.
class DownloadManager extends ChangeNotifier {
  DownloadManager();

  static final DownloadManager instance = DownloadManager();
  static const _prefsKey = 'downloads_v1';

  final Map<String, DownloadItem> _items = {};
  final Map<String, double?> _active = {}; // null value = size unknown
  final Map<String, String> _errors = {};
  final Map<String, http.Client> _clients = {};
  final Set<String> _cancelled = {};
  String? _dirPath;

  List<DownloadItem> get items {
    final list = _items.values.toList();
    list.sort((a, b) {
      final byNumber = a.hymnNumber.compareTo(b.hymnNumber);
      return byNumber != 0 ? byNumber : a.language.compareTo(b.language);
    });
    return list;
  }

  int get totalBytes => _items.values.fold(0, (sum, i) => sum + i.bytes);

  bool isDownloaded(String recordingId) => _items.containsKey(recordingId);
  bool isDownloading(String recordingId) => _active.containsKey(recordingId);
  double? progressOf(String recordingId) => _active[recordingId];
  String? errorOf(String recordingId) => _errors[recordingId];

  /// Where a downloaded recording lives on the phone, or null if it
  /// has not been downloaded.
  Uri? localUri(String recordingId) {
    final item = _items[recordingId];
    final dir = _dirPath;
    if (item == null || dir == null) return null;
    return Uri.file('$dir/${item.fileName}');
  }

  /// Call once at startup. Cleans up half-finished files and forgets
  /// any download whose file is missing or the wrong size.
  Future<void> init({String? directoryPath}) async {
    final dir = await _ensureDirectory(directoryPath);

    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.part')) {
        try {
          entity.deleteSync();
        } catch (_) {}
      }
    }

    _items.clear();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        for (final entry in jsonDecode(raw) as List) {
          try {
            final item = DownloadItem.fromJson(entry as Map<String, dynamic>);
            final file = File('${dir.path}/${item.fileName}');
            if (file.existsSync() && file.lengthSync() == item.bytes) {
              _items[item.recordingId] = item;
            }
          } catch (_) {
            // Skip a bad record rather than losing all downloads.
          }
        }
      } catch (_) {}
    }
    await _persist();
    notifyListeners();
  }

  Future<Directory> _ensureDirectory([String? override]) async {
    final existing = _dirPath;
    if (existing != null && override == null) return Directory(existing);

    final String path;
    if (override != null) {
      path = override;
    } else {
      final base = await getApplicationDocumentsDirectory();
      path = '${base.path}/downloads';
    }
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dirPath = path;
    return dir;
  }

  String _extensionOf(String storagePath) {
    final dot = storagePath.lastIndexOf('.');
    if (dot <= 0 || dot == storagePath.length - 1) return 'mp3';
    final ext = storagePath.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'mp3';
  }

  Future<void> download({
    required Recording recording,
    required Hymn hymn,
    required Uri url,
  }) async {
    final id = recording.id;
    if (_items.containsKey(id) || _active.containsKey(id)) return;

    _errors.remove(id);
    _cancelled.remove(id);
    _active[id] = 0.0;
    notifyListeners();

    final client = http.Client();
    _clients[id] = client;
    File? partial;

    try {
      final dir = await _ensureDirectory();
      final fileName = '$id.${_extensionOf(recording.storagePath)}';
      partial = File('${dir.path}/$fileName.part');
      final finalFile = File('${dir.path}/$fileName');

      final response = await client.send(http.Request('GET', url));
      if (response.statusCode != 200) {
        throw HttpException('Unexpected status ${response.statusCode}');
      }

      // Only trust the length when the file is not compressed in transit.
      final total = response.headers.containsKey('content-encoding')
          ? null
          : response.contentLength;

      final sink = partial.openWrite();
      var received = 0;
      var lastNotified = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (received - lastNotified >= 65536) {
            lastNotified = received;
            _active[id] = (total != null && total > 0) ? received / total : null;
            notifyListeners();
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (received == 0 || (total != null && received != total)) {
        throw const FormatException('Incomplete download');
      }

      if (finalFile.existsSync()) finalFile.deleteSync();
      await partial.rename(finalFile.path);

      _items[id] = DownloadItem(
        recordingId: id,
        hymnId: hymn.id,
        hymnNumber: hymn.number,
        hymnTitle: hymn.title,
        language: recording.language,
        fileName: fileName,
        bytes: received,
      );
      await _persist();
    } catch (_) {
      if (!_cancelled.contains(id)) {
        _errors[id] =
            'The download did not finish. Check your connection and try again.';
      }
    } finally {
      client.close();
      _clients.remove(id);
      _active.remove(id);
      _cancelled.remove(id);
      try {
        if (partial != null && partial.existsSync()) partial.deleteSync();
      } catch (_) {}
      notifyListeners();
    }
  }

  void cancel(String recordingId) {
    if (_active.containsKey(recordingId)) {
      _cancelled.add(recordingId);
      _clients[recordingId]?.close();
    }
  }

  Future<void> remove(String recordingId) async {
    final item = _items[recordingId];
    if (item == null) return;

    final dir = _dirPath;
    if (dir != null) {
      try {
        final file = File('$dir/${item.fileName}');
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
    }
    _items.remove(recordingId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_items.values.map((i) => i.toJson()).toList()),
    );
  }
}