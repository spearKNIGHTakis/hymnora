import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/models/recording.dart';

void main() {
  test('parses a valid recording record', () {
    final r = Recording.fromJson({
      'id': 'r1',
      'hymn_id': 'h1',
      'language': 'Twi',
      'storage_path': 'file.mp3',
    });
    expect(r.hymnId, 'h1');
    expect(r.storagePath, 'file.mp3');
  });

  test('rejects an empty storage path', () {
    expect(
      () => Recording.fromJson({
        'id': 'r1',
        'hymn_id': 'h1',
        'language': 'Twi',
        'storage_path': '  ',
      }),
      throwsFormatException,
    );
  });
}