import 'package:meta/meta.dart';

import '../../../core/money/money.dart';

/// A position in one symbol, held at average cost.
///
/// The stored state is (quantity, **total** cost) rather than (quantity,
/// average cost). Average cost is derived on demand. This matters: an average
/// price is usually not a whole number of paise, so storing it would round on
/// every buy and let the error compound across a long trading session. Keeping
/// the aggregate exact means `totalCost` always equals the rupees actually
/// spent, and P&L reconciles to the last paisa.
@immutable
class Holding {
  const Holding({
    required this.symbol,
    required this.quantity,
    required this.totalCost,
  }) : assert(quantity >= 0, 'Quantity cannot be negative');

  factory Holding.opened({
    required String symbol,
    required int quantity,
    required Money price,
  }) {
    return Holding(
      symbol: symbol,
      quantity: quantity,
      totalCost: price * quantity,
    );
  }

  final String symbol;
  final int quantity;

  /// Exact rupees paid for the current position.
  final Money totalCost;

  /// Display-only average cost per share, rounded to the nearest paisa.
  Money get averageCost => totalCost.dividedBy(quantity);

  bool get isEmpty => quantity == 0;

  Money currentValue(Money ltp) => ltp * quantity;

  Money unrealisedPnl(Money ltp) => currentValue(ltp) - totalCost;

  double pnlPercent(Money ltp) => unrealisedPnl(ltp).percentOf(totalCost);

  /// Adds [quantity] shares bought at [price], accumulating exact cost.
  Holding applyBuy({required int quantity, required Money price}) {
    return Holding(
      symbol: symbol,
      quantity: this.quantity + quantity,
      totalCost: totalCost + price * quantity,
    );
  }

  /// Removes [quantity] shares, reducing the cost basis proportionally so the
  /// average cost of what remains is unchanged — standard average-cost
  /// accounting. Returns `null` once the position is fully closed, which is how
  /// a sold-out holding disappears from the portfolio.
  Holding? applySell({required int quantity}) {
    final remaining = this.quantity - quantity;
    if (remaining <= 0) return null;
    return Holding(
      symbol: symbol,
      quantity: remaining,
      totalCost: Money((totalCost.paise * remaining / this.quantity).round()),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'symbol': symbol,
        'quantity': quantity,
        'totalCostPaise': totalCost.paise,
      };

  /// Returns `null` for malformed rows so one bad entry cannot take down the
  /// whole restored portfolio.
  static Holding? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final symbol = json['symbol'];
    final quantity = json['quantity'];
    final cost = json['totalCostPaise'];
    if (symbol is! String || quantity is! int || cost is! int) return null;
    if (quantity <= 0) return null;
    return Holding(
      symbol: symbol,
      quantity: quantity,
      totalCost: Money(cost),
    );
  }
}
