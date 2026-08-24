import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../../market/application/market_data_service.dart';
import '../domain/holding.dart';

/// Aggregate portfolio figures at one instant in time.
@immutable
class PortfolioSummary {
  const PortfolioSummary({
    required this.invested,
    required this.currentValue,
    required this.positions,
  });

  static const PortfolioSummary empty = PortfolioSummary(
    invested: Money.zero,
    currentValue: Money.zero,
    positions: 0,
  );

  final Money invested;
  final Money currentValue;
  final int positions;

  Money get pnl => currentValue - invested;

  double get pnlPercent => pnl.percentOf(invested);

  bool get isEmpty => positions == 0;

  /// Sums the same per-symbol quotes the rows render.
  ///
  /// Called inside the aggregate widget's build, after the service has flushed
  /// every pending tick for the frame. Because the flush is atomic — all
  /// notifiers written, *then* the epoch bumped — the total shown always equals
  /// the sum of the visible rows; there is no window in which half the prices
  /// are new and half are stale.
  static PortfolioSummary of(
    Iterable<Holding> holdings,
    MarketDataService market,
  ) {
    var invested = Money.zero;
    var currentValue = Money.zero;
    var positions = 0;

    for (final holding in holdings) {
      final quote = market.quoteOrNull(holding.symbol);
      invested += holding.totalCost;
      // A holding whose symbol left the universe still counts at cost rather
      // than vanishing from the total.
      currentValue +=
          quote == null ? holding.totalCost : holding.currentValue(quote.ltp);
      positions++;
    }

    return PortfolioSummary(
      invested: invested,
      currentValue: currentValue,
      positions: positions,
    );
  }
}
