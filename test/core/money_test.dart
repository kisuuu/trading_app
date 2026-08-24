import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/core/money/money.dart';
import 'package:trading_app/src/core/money/money_formatter.dart';

void main() {
  group('Money arithmetic', () {
    test('adds and subtracts exactly', () {
      expect(const Money(1050) + const Money(2575), const Money(3625));
      expect(const Money(1050) - const Money(2575), const Money(-1525));
    });

    test('multiplies by a share quantity without drift', () {
      // 1010.10 x 100 is 101009.99999999999 in binary floating point.
      const price = Money(101010);
      expect((price * 100).paise, 10101000);
      expect(MoneyFormatter.rupees(price * 100), '₹1,01,010.00');
    });

    test('accumulates 1000 additions with no rounding error', () {
      var total = Money.zero;
      for (var i = 0; i < 1000; i++) {
        total += const Money(10); // 10 paise
      }
      expect(total, const Money(10000));
      expect(total.asRupees, 100.0);
    });

    test('divides with half-away-from-zero rounding', () {
      expect(const Money(1000).dividedBy(4), const Money(250));
      expect(const Money(1000).dividedBy(3), const Money(333));
      expect(const Money(5).dividedBy(2), const Money(3));
      expect(const Money(-5).dividedBy(2), const Money(-3));
      expect(const Money(100).dividedBy(0), Money.zero);
    });

    test('percentOf returns zero for a zero base instead of NaN', () {
      expect(const Money(500).percentOf(Money.zero), 0);
      expect(const Money(50).percentOf(const Money(1000)), 5);
    });
  });

  group('Money parsing', () {
    test('accepts decimal rupee strings', () {
      expect(Money.tryParseRupees('1234.50'), const Money(123450));
      expect(Money.tryParseRupees(' 1,234.50 '), const Money(123450));
      expect(Money.tryParseRupees('-10'), const Money(-1000));
    });

    test('rejects junk', () {
      expect(Money.tryParseRupees(''), isNull);
      expect(Money.tryParseRupees('abc'), isNull);
      expect(Money.tryParseRupees('1.2.3'), isNull);
    });
  });

  group('MoneyFormatter', () {
    test('groups digits the Indian way', () {
      expect(MoneyFormatter.rupees(const Money(100)), '₹1.00');
      expect(MoneyFormatter.rupees(const Money(99999)), '₹999.99');
      expect(MoneyFormatter.rupees(const Money(123456789)), '₹12,34,567.89');
      expect(MoneyFormatter.rupees(const Money(100000000)), '₹10,00,000.00');
    });

    test('always pads paise to two digits', () {
      expect(MoneyFormatter.rupees(const Money(1005)), '₹10.05');
      expect(MoneyFormatter.rupees(const Money(1050)), '₹10.50');
    });

    test('shows an explicit sign for changes', () {
      expect(MoneyFormatter.signedRupees(const Money(1250)), '+₹12.50');
      expect(MoneyFormatter.signedRupees(const Money(-1250)), '-₹12.50');
      expect(MoneyFormatter.signedPercent(0.4237), '+0.42%');
      expect(MoneyFormatter.signedPercent(-1.005), '-1.00%');
      expect(MoneyFormatter.signedPercent(double.nan), '+0.00%');
    });

    test('compacts large portfolio figures', () {
      expect(MoneyFormatter.compactRupees(const Money(1234500000)), '₹1.23Cr');
      expect(MoneyFormatter.compactRupees(const Money(12345000)), '₹1.23L');
      expect(MoneyFormatter.compactRupees(const Money(123450)), '₹1,234.50');
    });
  });
}
