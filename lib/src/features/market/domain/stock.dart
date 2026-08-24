import 'package:meta/meta.dart';

import '../../../core/money/money.dart';

/// A tradable instrument in the (fixed) mock universe.
@immutable
class Stock {
  const Stock({
    required this.symbol,
    required this.name,
    required this.previousClose,
    required this.volatilityBps,
  });

  final String symbol;
  final String name;

  /// Yesterday's close — the reference the day's change is measured against.
  final Money previousClose;

  /// Per-tick volatility in basis points (1 bp = 0.01%). Drives how lively each
  /// symbol looks; banks tick tighter than high-beta names.
  final int volatilityBps;

  @override
  bool operator ==(Object other) => other is Stock && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;
}

/// The ten instruments used throughout the app.
///
/// This is the single place the universe is defined; screens, the feed and the
/// stock picker all read from here so they can never drift apart.
abstract final class StockUniverse {
  static const List<Stock> stocks = <Stock>[
    Stock(
      symbol: 'RELIANCE',
      name: 'Reliance Industries',
      previousClose: Money(295040),
      volatilityBps: 9,
    ),
    Stock(
      symbol: 'TCS',
      name: 'Tata Consultancy Services',
      previousClose: Money(412580),
      volatilityBps: 7,
    ),
    Stock(
      symbol: 'INFY',
      name: 'Infosys',
      previousClose: Money(186525),
      volatilityBps: 8,
    ),
    Stock(
      symbol: 'HDFCBANK',
      name: 'HDFC Bank',
      previousClose: Money(167310),
      volatilityBps: 6,
    ),
    Stock(
      symbol: 'ICICIBANK',
      name: 'ICICI Bank',
      previousClose: Money(124875),
      volatilityBps: 6,
    ),
    Stock(
      symbol: 'SBIN',
      name: 'State Bank of India',
      previousClose: Money(81640),
      volatilityBps: 10,
    ),
    Stock(
      symbol: 'ITC',
      name: 'ITC Limited',
      previousClose: Money(44725),
      volatilityBps: 5,
    ),
    Stock(
      symbol: 'LT',
      name: 'Larsen & Toubro',
      previousClose: Money(367190),
      volatilityBps: 9,
    ),
    Stock(
      symbol: 'BHARTIARTL',
      name: 'Bharti Airtel',
      previousClose: Money(159880),
      volatilityBps: 8,
    ),
    Stock(
      symbol: 'AXISBANK',
      name: 'Axis Bank',
      previousClose: Money(113455),
      volatilityBps: 7,
    ),
  ];

  static final Map<String, Stock> _bySymbol = <String, Stock>{
    for (final stock in stocks) stock.symbol: stock,
  };

  static final List<String> symbols = <String>[
    for (final stock in stocks) stock.symbol,
  ];

  /// Returns the stock for [symbol], or `null` if it is not in the universe.
  ///
  /// Persisted data is validated against this: a watchlist restored from an
  /// older build that names a delisted symbol simply drops it instead of
  /// rendering a broken row.
  static Stock? find(String symbol) => _bySymbol[symbol];

  static bool contains(String symbol) => _bySymbol.containsKey(symbol);

  static String nameOf(String symbol) => _bySymbol[symbol]?.name ?? symbol;
}
