import 'package:flutter_test/flutter_test.dart';
import 'package:lavenga/core/money/money.dart';

void main() {
  group('Money', () {
    test('formats whole and fractional amounts with grouping', () {
      expect(Money.taka(12500).format(), '৳12,500');
      expect(Money.fromMinor(1250050).format(), '৳12,500.50');
      expect(Money.zero.format(alwaysShowDecimals: true), '৳0.00');
      expect(Money.fromMinor(-150).format(), '-৳1.50');
    });

    test('parses user input without doubles', () {
      expect(Money.parse('2,500.5'), Money.fromMinor(250050));
      expect(Money.parse('10'), Money.taka(10));
      expect(() => Money.parse('abc'), throwsFormatException);
      expect(() => Money.parse('1.234'), throwsFormatException);
    });

    test('percent rounds half away from zero in basis points', () {
      expect(Money.taka(1000).percent(1500), Money.taka(150)); // 15%
      expect(Money.fromMinor(1).percent(5000), Money.fromMinor(1)); // 0.5 -> 1
      expect(Money.fromMinor(-1).percent(5000), Money.fromMinor(-1));
    });

    test('allocate always sums to the original amount', () {
      final parts = Money.fromMinor(10000).allocate([1, 1, 1]);
      expect(parts.map((m) => m.minor), [3333, 3333, 3334]);
      expect(parts.fold(Money.zero, (a, b) => a + b), Money.fromMinor(10000));
    });

    test('clamping helps floor remaining due at zero', () {
      final due = Money.taka(1000) - Money.taka(1200);
      expect(due.clampMin(Money.zero), Money.zero);
    });
  });
}
