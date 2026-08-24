import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import 'holding.dart';

/// Cash balance and open positions, held together as one immutable value.
///
/// Wallet and holdings are deliberately one aggregate rather than two: an order
/// moves both, and persisting them as a single record makes a torn write —
/// cash debited but the holding lost — impossible.
@immutable
class Portfolio {
  const Portfolio({required this.cash, required this.holdings});

  /// Opening balance for a fresh install: ₹10,00,000 of simulated margin.
  static const Money openingCash = Money(100000000);

  static const Portfolio initial = Portfolio(
    cash: openingCash,
    holdings: <String, Holding>{},
  );

  final Money cash;

  /// Open positions keyed by symbol.
  final Map<String, Holding> holdings;

  bool get isEmpty => holdings.isEmpty;

  Holding? holdingOf(String symbol) => holdings[symbol];

  int quantityHeld(String symbol) => holdings[symbol]?.quantity ?? 0;

  /// Total exact cost basis across all positions.
  Money get invested => holdings.values.fold(
        Money.zero,
        (total, holding) => total + holding.totalCost,
      );

  Portfolio copyWith({Money? cash, Map<String, Holding>? holdings}) {
    return Portfolio(
      cash: cash ?? this.cash,
      holdings: holdings ?? this.holdings,
    );
  }

  /// Returns a copy with [holding] stored, or the symbol removed when the
  /// position has been fully closed.
  Portfolio withHolding(String symbol, Holding? holding) {
    final next = Map<String, Holding>.of(holdings);
    if (holding == null || holding.isEmpty) {
      next.remove(symbol);
    } else {
      next[symbol] = holding;
    }
    return copyWith(holdings: next);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'cashPaise': cash.paise,
        'holdings': <Object?>[
          for (final holding in holdings.values) holding.toJson(),
        ],
      };

  static Portfolio fromJson(Map<String, Object?>? json) {
    if (json == null) return initial;
    final cash = json['cashPaise'];
    final rows = json['holdings'];
    if (cash is! int) return initial;

    final restored = <String, Holding>{};
    if (rows is List<Object?>) {
      for (final row in rows) {
        final holding = Holding.fromJson(row);
        if (holding != null) restored[holding.symbol] = holding;
      }
    }
    return Portfolio(cash: Money(cash), holdings: restored);
  }
}
