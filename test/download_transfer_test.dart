import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hymnora/models/hymn.dart';
import 'package:hymnora/models/recording.dart';
import 'package:hymnora/services/download_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const hymn = Hymn(id: 'h1', number: 'PH1', title: 'Title', language: 'Twi');
  const recording = Recording(
    id: 'r1',
    hymnId: 'h1',
    language: 'Twi',
    storagePath: 'h1/twi.mp3',
  );
  late Directory directory;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('hymnora_download_');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  test(
    'download becomes playable only after all bytes are saved and persists',
    () async {
      final manager = DownloadManager(
        clientFactory: () => MockClient((_) async => http.Response('abc', 200)),
      );
      await manager.init(directoryPath: directory.path);
      await manager.download(
        recording: recording,
        hymn: hymn,
        url: Uri.parse('https://example.com/audio.mp3'),
      );
      expect(manager.isDownloaded('r1'), isTrue);
      expect(manager.totalBytes, 3);
      expect(await File.fromUri(manager.localUri('r1')!).readAsString(), 'abc');
      final reopened = DownloadManager();
      await reopened.init(directoryPath: directory.path);
      expect(reopened.items.single.recordingId, 'r1');
    },
  );
  test(
    'early cancellation does not save an audio file or show an error',
    () async {
      final manager = DownloadManager(
        clientFactory: () => MockClient((_) async => http.Response('abc', 200)),
      );
      await manager.init(directoryPath: directory.path);
      final pending = manager.download(
        recording: recording,
        hymn: hymn,
        url: Uri.parse('https://example.com/audio.mp3'),
      );
      manager.cancel('r1');
      await pending;
      expect(manager.isDownloaded('r1'), isFalse);
      expect(manager.isDownloading('r1'), isFalse);
      expect(manager.errorOf('r1'), isNull);
      expect(directory.listSync(), isEmpty);
    },
  );
  test(
    'HTTP failure exposes retryable error and leaves no partial download',
    () async {
      final manager = DownloadManager(
        clientFactory: () =>
            MockClient((_) async => http.Response('missing', 404)),
      );
      await manager.init(directoryPath: directory.path);
      await manager.download(
        recording: recording,
        hymn: hymn,
        url: Uri.parse('https://example.com/audio.mp3'),
      );
      expect(manager.errorOf('r1'), isNotNull);
      expect(manager.items, isEmpty);
      expect(directory.listSync(), isEmpty);
    },
  );
}
