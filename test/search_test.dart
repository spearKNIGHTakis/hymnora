import 'package:flutter_test/flutter_test.dart';
import 'package:hymnora/repositories/hymn_repository.dart';

void main() {
  test('removes characters that could break a filter', () {
    expect(sanitizeSearchQuery('  PH1,(x)%  '), 'PH1  x');
  });

  test('leaves normal text alone', () {
    expect(sanitizeSearchQuery('monkafo'), 'monkafo');
  });
}