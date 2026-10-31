import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/models/download_item.dart';
import 'package:hymnora/services/download_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

DownloadItem _item(String id, int bytes) => DownloadItem(
  recordingId: id,
  hymnId: 'h1',
  hymnNumber: 'PH1',
  hymnTitle: 'Title',
  language: 'Twi',
  fileName: '$id.mp3',
  bytes: bytes,
);

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hymnora_test');
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('download record survives a JSON round trip', () {
    final copy = DownloadItem.fromJson(_item('r1', 10).toJson());
    expect(copy.recordingId, 'r1');
    expect(copy.bytes, 10);
  });

  test('keeps complete files and forgets missing or wrong-size ones', () async {
    File('${dir.path}/ok.mp3').writeAsBytesSync([1, 2, 3]);
    File('${dir.path}/short.mp3').writeAsBytesSync([1]);
    SharedPreferences.setMockInitialValues({
      'downloads_v1': jsonEncode([
        _item('ok', 3).toJson(),
        _item('short', 3).toJson(),
        _item('gone', 3).toJson(),
      ]),
    });

    final manager = DownloadManager();
    await manager.init(directoryPath: dir.path);

    expect(manager.isDownloaded('ok'), isTrue);
    expect(manager.isDownloaded('short'), isFalse);
    expect(manager.isDownloaded('gone'), isFalse);
  });

  test('deletes leftover partial downloads at startup', () async {
    final partial = File('${dir.path}/x.mp3.part')..writeAsBytesSync([1, 2]);
    SharedPreferences.setMockInitialValues({});

    final manager = DownloadManager();
    await manager.init(directoryPath: dir.path);

    expect(partial.existsSync(), isFalse);
  });

  test('removing a download deletes its file', () async {
    final file = File('${dir.path}/ok.mp3')..writeAsBytesSync([1, 2, 3]);
    SharedPreferences.setMockInitialValues({
      'downloads_v1': jsonEncode([_item('ok', 3).toJson()]),
    });

    final manager = DownloadManager();
    await manager.init(directoryPath: dir.path);
    await manager.remove('ok');

    expect(manager.isDownloaded('ok'), isFalse);
    expect(file.existsSync(), isFalse);
  });
}
