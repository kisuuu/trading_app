import 'package:meta/meta.dart';

/// An exact monetary amount, stored as a whole number of **paise**.
///
/// Every price, order value, cost basis and P&L figure in the app flows
/// through this type. Money is never represented as a `double`, so repeated
/// buys, sells and P&L recomputations cannot accumulate binary-floating-point
/// drift (the classic `0.1 + 0.2 != 0.3` class of bug).
///
/// `double` appears only at the very edge of the system: formatting for
/// display, and percentage figures, which are inherently approximate.
@immutable
class Money implements Comparable<Money> {
  const Money(this.paise);

  /// Builds a [Money] from a rupee amount, rounding half-away-from-zero to the
  /// nearest paisa. Intended for seed data and user input, not for arithmetic.
  factory Money.fromRupees(num rupees) => Money((rupees * 100).round());

  /// Parses a user-entered rupee string (`"1234.50"`). Returns `null` when the
  /// text is not a finite decimal number.
  static Money? tryParseRupees(String input) {
    final trimmed = input.trim().replaceAll(',', '');
    if (trimmed.isEmpty) return null;
    final value = double.tryParse(trimmed);
    if (value == null || !value.isFinite) return null;
    return Money.fromRupees(value);
  }

  /// The amount in paise. 1 rupee == 100 paise.
  final int paise;

  static const Money zero = Money(0);

  /// Exact multiplication by a share quantity — the only multiplication the
  /// domain needs, and it stays in integer space.
  Money operator *(int quantity) => Money(paise * quantity);

  Money operator +(Money other) => Money(paise + other.paise);

  Money operator -(Money other) => Money(paise - other.paise);

  Money operator -() => Money(-paise);

  bool operator >(Money other) => paise > other.paise;

  bool operator >=(Money other) => paise >= other.paise;

  bool operator <(Money other) => paise < other.paise;

  bool operator <=(Money other) => paise <= other.paise;

  bool get isZero => paise == 0;

  bool get isNegative => paise < 0;

  bool get isPositive => paise > 0;

  Money get abs => Money(paise.abs());

  /// Divides an amount into [parts] equal shares, rounding half-up.
  ///
  /// Used for derived, display-only figures such as average cost per share.
  /// The exact cost basis is always kept as (total cost, quantity) so that no
  /// rounding is ever folded back into stored state.
  Money dividedBy(int parts) {
    if (parts == 0) return Money.zero;
    final quotient = paise ~/ parts;
    final remainder = paise.remainder(parts).abs();
    final roundsUp = remainder * 2 >= parts.abs();
    if (!roundsUp) return Money(quotient);
    return Money(quotient + (paise.isNegative != parts.isNegative ? -1 : 1));
  }

  /// This amount as a percentage of [base]. Returns `0` for a zero base rather
  /// than infinity/NaN, so callers never have to guard the display path.
  double percentOf(Money base) {
    if (base.paise == 0) return 0;
    return paise / base.paise * 100;
  }

  /// Rupee value as a `double`. Display and percentage use only — never feed
  /// this back into arithmetic that produces stored state.
  double get asRupees => paise / 100;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => 'Money(${asRupees.toStringAsFixed(2)})';
}
