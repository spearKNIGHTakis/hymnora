import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/hymn.dart';
import '../models/stanza.dart';
import 'catalogue_cache.dart';

class BundledCatalogue {
  static Future<void>? _loading;
  static final Map<String, bool> _visibility = {};
  static bool isVisible(String id) =>
      _visibility[_remoteToLocal[id] ?? id] ?? true;
  static void applyOverrides(List<Map<String, dynamic>> rows) {
    _visibility.clear();
    for (final row in rows) {
      if (row['source_key'] is String && row['is_visible'] is bool) {
        _visibility[row['source_key']] = row['is_visible'];
      }
    }
  }

  static final Map<String, Map<String, dynamic>> _rows = {};
  static final Map<String, String> _byNumber = {};
  static final Map<String, String> _searchText = {};
  static final Map<String, String> _remoteToLocal = {};
  static final Map<String, Hymn> _localToRemote = {};
  static Future<void> load() => _loading ??= _load();
  static String normalize(String value) =>
      value.toLowerCase().replaceAll('ɛ', 'e').replaceAll('ɔ', 'o');
  static String _key(Hymn hymn) =>
      '${hymn.language.toLowerCase()}|${canonicalHymnNumber(hymn.number).toUpperCase().replaceAll(' ', '')}';

  static Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/hymns.json');
    for (final item in jsonDecode(raw) as List) {
      final row = Map<String, dynamic>.from(item as Map);
      final hymn = Hymn.fromJson(row);
      _rows[hymn.id] = row;
      _byNumber[_key(hymn)] = hymn.id;
      final lyrics = (row['stanzas'] as List).map((s) => s['body']).join(' ');
      _searchText[hymn.id] = normalize('${hymn.number} ${hymn.title} $lyrics');
    }
    applyOverrides(await CatalogueCache.read('visibility') ?? []);
    final cached = await CatalogueCache.read('hymns') ?? [];
    for (final row in cached) {
      registerRemote(
        Hymn.fromJson(row),
        sourceKey: row['source_key'] as String?,
        published: row.containsKey('content_version'),
      );
    }
  }

  static Hymn registerRemote(
    Hymn remote, {
    String? sourceKey,
    bool published = false,
  }) {
    final localId = (sourceKey != null && _rows.containsKey(sourceKey))
        ? sourceKey
        : _byNumber[_key(remote)];
    if (localId == null) return remote;
    _remoteToLocal[remote.id] = localId;
    _localToRemote[localId] = remote;
    if (published) {
      _rows[localId] = {
        ..._rows[localId]!,
        'number': remote.number,
        'title': remote.title,
        'language': remote.language,
      };
      final lyrics = (_rows[localId]!['stanzas'] as List)
          .map((s) => s['body'])
          .join(' ');
      _searchText[localId] = normalize(
        '${remote.number} ${remote.title} $lyrics',
      );
    }
    return Hymn.fromJson(_rows[localId]!);
  }

  static Map<String, dynamic>? source(String id) =>
      _rows[_remoteToLocal[id] ?? id];
  static Hymn? hymn(String id) {
    final row = source(id);
    if (row == null) return null;
    final parsed = Hymn.fromJson(row);
    // Keep existing favourite IDs stable for installations predating the bundle.
    return Hymn(
      id: id,
      number: parsed.number,
      title: parsed.title,
      language: parsed.language,
    );
  }

  static String remoteId(String id) => _localToRemote[id]?.id ?? id;
  static bool isLocal(String id) => source(id) != null;
  static bool get available => _rows.isNotEmpty;
  static List<String> get languages =>
      _rows.values.map((r) => r['language'] as String).toSet().toList()..sort();
  static List<Stanza> stanzas(String id) =>
      (source(id)?['stanzas'] as List? ?? [])
          .map((r) => Stanza.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  static List<Hymn> search({String query = '', String? language}) {
    final q = normalize(query.trim());
    final result = _rows.values
        .where(
          (row) =>
              isVisible(row['id'] as String) &&
              (language == null || row['language'] == language) &&
              (q.isEmpty || _searchText[row['id']]!.contains(q)),
        )
        .map(Hymn.fromJson)
        .toList();
    result.sort((a, b) {
      final ae = normalize(a.number) == q;
      final be = normalize(b.number) == q;
      if (ae != be) return ae ? -1 : 1;
      return compare(a, b);
    });
    return result;
  }

  static int compare(Hymn a, Hymn b) {
    final language = a.language.compareTo(b.language);
    if (language != 0) return language;
    final an = int.tryParse(a.number.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final bn = int.tryParse(b.number.replaceAll(RegExp(r'\D'), '')) ?? 0;
    return an != bn ? an.compareTo(bn) : a.number.compareTo(b.number);
  }
}
