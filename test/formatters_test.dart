import 'package:flutter_test/flutter_test.dart';

import 'package:banquet_catering_app/core/utils/formatters.dart';

void main() {
  group('Formatters.currency', () {
    test('formats whole rupees with INR symbol', () {
      expect(Formatters.currency(1234), '\u20B91,234');
      expect(Formatters.currency(0), '\u20B90');
    });

    test('rounds decimals (decimalDigits = 0)', () {
      expect(Formatters.currency(99.4), '\u20B999');
      expect(Formatters.currency(99.5), '\u20B9100');
    });
  });

  group('Formatters.date', () {
    test('returns "dd MMM yyyy" format', () {
      final d = DateTime(2026, 4, 15);
      expect(Formatters.date(d), '15 Apr 2026');
    });
  });
}
