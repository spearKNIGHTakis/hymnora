import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/models/stanza.dart';

void main() {
  test('parses a chorus and keeps line breaks', () {
    final s = Stanza.fromJson({
      'id': 's1',
      'position': 2,
      'kind': 'chorus',
      'body': 'line one\nline two',
    });
    expect(s.isChorus, isTrue);
    expect(s.body, 'line one\nline two');
  });

  test('rejects a stanza with a wrong type', () {
    expect(
      () => Stanza.fromJson({
        'id': 's1',
        'position': 'two',
        'kind': 'verse',
        'body': 'x',
      }),
      throwsFormatException,
    );
  });
}
