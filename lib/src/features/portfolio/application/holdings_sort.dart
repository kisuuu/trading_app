import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../market/application/market_data_service.dart';
import '../../market/application/market_providers.dart';
import '../domain/holding.dart';
import 'portfolio_controller.dart';

enum HoldingsSort {
  pnlDescending('P&L: high to low'),
  pnlAscending('P&L: low to high'),
  currentValueDescending('Value: high to low'),
  symbolAscending('Symbol: A to Z');

  const HoldingsSort(this.label);

  final String label;

  /// Whether this ordering depends on live prices, and therefore has to be
  /// re-evaluated as ticks arrive.
  bool get isPriceDependent => this != HoldingsSort.symbolAscending;
}

class HoldingsSortController extends Notifier<HoldingsSort> {
  @override
  HoldingsSort build() => HoldingsSort.pnlDescending;

  void set(HoldingsSort sort) => state = sort;
}

final NotifierProvider<HoldingsSortController, HoldingsSort> holdingsSortProvider =
    NotifierProvider<HoldingsSortController, HoldingsSort>(
  HoldingsSortController.new,
);

/// Publishes the display order of the holdings list as symbols.
///
/// A P&L sort is live: a position crossing from loss to gain has to move up the
/// list. Naively that means re-sorting on every tick and rebuilding the whole
/// list — expensive, and it would fight the per-row notifiers that exist
/// precisely to avoid list-wide rebuilds.
///
/// So the sort is recomputed on each flush (cheap: a handful of integer
/// comparisons) but only *published* when the resulting sequence actually
/// differs. Prices move constantly; the order changes rarely. The list rebuilds
/// on the rare event, while the rows keep updating their own numbers.
class HoldingsOrderNotifier extends ValueNotifier<List<String>> {
  HoldingsOrderNotifier({
    required MarketDataService market,
    required List<Holding> holdings,
    required HoldingsSort sort,
  })  : _market = market,
        _holdings = holdings,
        _sort = sort,
        super(const <String>[]) {
    value = _computeOrder();
    if (sort.isPriceDependent) {
      _market.epoch.addListener(_onFlush);
    }
  }

  final MarketDataService _market;
  final List<Holding> _holdings;
  final HoldingsSort _sort;

  void _onFlush() {
    final next = _computeOrder();
    if (!listEquals(next, value)) value = next;
  }

  List<String> _computeOrder() {
    final sorted = List<Holding>.of(_holdings);
    sorted.sort(_compare);
    return <String>[for (final holding in sorted) holding.symbol];
  }

  int _compare(Holding a, Holding b) {
    final result = switch (_sort) {
      HoldingsSort.symbolAscending => a.symbol.compareTo(b.symbol),
      HoldingsSort.pnlDescending => _pnl(b).compareTo(_pnl(a)),
      HoldingsSort.pnlAscending => _pnl(a).compareTo(_pnl(b)),
      HoldingsSort.currentValueDescending => _value(b).compareTo(_value(a)),
    };
    // Symbol is the tiebreaker so equal figures never cause rows to swap
    // places at random between frames.
    return result != 0 ? result : a.symbol.compareTo(b.symbol);
  }

  int _pnl(Holding holding) {
    final quote = _market.quoteOrNull(holding.symbol);
    return quote == null ? 0 : holding.unrealisedPnl(quote.ltp).paise;
  }

  int _value(Holding holding) {
    final quote = _market.quoteOrNull(holding.symbol);
    return quote == null
        ? holding.totalCost.paise
        : holding.currentValue(quote.ltp).paise;
  }

  @override
  void dispose() {
    if (_sort.isPriceDependent) {
      _market.epoch.removeListener(_onFlush);
    }
    super.dispose();
  }
}

/// Rebuilt only when the position set or the chosen sort changes; live
/// reordering happens inside the notifier.
final Provider<HoldingsOrderNotifier> holdingsOrderProvider =
    Provider<HoldingsOrderNotifier>((ref) {
  final notifier = HoldingsOrderNotifier(
    market: ref.watch(marketDataServiceProvider),
    holdings: ref.watch(holdingsProvider),
    sort: ref.watch(holdingsSortProvider),
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});
