import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/models/hymn.dart';

void main() {
  test('parses a valid hymn record', () {
    final hymn = Hymn.fromJson({
      'id': 'abc',
      'number': 'T1',
      'title': 'Test title',
      'language': 'Twi',
    });
    expect(hymn.id, 'abc');
    expect(hymn.number, 'T1');
  });

  test('rejects a record with missing fields', () {
    expect(
      () => Hymn.fromJson({'id': 'abc', 'title': 'No number'}),
      throwsFormatException,
    );
  });
}