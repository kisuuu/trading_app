import 'money.dart';

/// Formats money and percentages using the Indian digit grouping convention
/// (`12,34,567.89`) that traders here expect.
///
/// Hand-rolled rather than pulling in `intl`: the rule is small, and keeping it
/// local means the app has no locale-data initialisation step before first
/// paint.
abstract final class MoneyFormatter {
  static const String rupeeSign = '₹';

  /// `₹1,234.50` — the canonical price/value format.
  static String rupees(Money amount, {bool withSymbol = true}) {
    final sign = amount.isNegative ? '-' : '';
    final totalPaise = amount.paise.abs();
    final whole = totalPaise ~/ 100;
    final fraction = (totalPaise % 100).toString().padLeft(2, '0');
    final symbol = withSymbol ? rupeeSign : '';
    return '$sign$symbol${_group(whole)}.$fraction';
  }

  /// `+₹1,234.50` / `-₹1,234.50` — for changes and P&L, where the sign carries
  /// meaning and should be visible even when positive.
  static String signedRupees(Money amount) {
    final formatted = rupees(amount.abs);
    if (amount.isNegative) return '-$formatted';
    return '+$formatted';
  }

  /// `+1.24%` / `-1.24%`.
  static String signedPercent(double percent) {
    final safe = percent.isFinite ? percent : 0.0;
    final sign = safe < 0 ? '-' : '+';
    return '$sign${safe.abs().toStringAsFixed(2)}%';
  }

  /// Compact form for the portfolio summary: `₹1.24L`, `₹3.40Cr`.
  static String compactRupees(Money amount) {
    final sign = amount.isNegative ? '-' : '';
    final rupeeValue = amount.abs.paise / 100;
    if (rupeeValue >= 10000000) {
      return '$sign$rupeeSign${(rupeeValue / 10000000).toStringAsFixed(2)}Cr';
    }
    if (rupeeValue >= 100000) {
      return '$sign$rupeeSign${(rupeeValue / 100000).toStringAsFixed(2)}L';
    }
    return rupees(amount);
  }

  /// Indian grouping: the last three digits, then two-digit groups.
  /// `1234567` -> `12,34,567`.
  static String _group(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;
    final last3 = digits.substring(digits.length - 3);
    var remaining = digits.substring(0, digits.length - 3);
    final groups = <String>[];
    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) groups.insert(0, remaining);
    return '${groups.join(',')},$last3';
  }
}
