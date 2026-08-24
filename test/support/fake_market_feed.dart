import 'dart:async';

import 'package:trading_app/src/core/money/money.dart';
import 'package:trading_app/src/features/market/data/market_feed.dart';
import 'package:trading_app/src/features/market/domain/quote.dart';
import 'package:trading_app/src/features/market/domain/stock.dart';

/// Deterministic feed for tests: no timers, ticks only when told to.
class FakeMarketFeed implements MarketFeed {
  FakeMarketFeed()
      : _quotes = <String, Quote>{
          for (final stock in StockUniverse.stocks)
            stock.symbol: Quote.initial(
              symbol: stock.symbol,
              previousClose: stock.previousClose,
            ),
        };

  final Map<String, Quote> _quotes;
  final StreamController<Quote> _controller =
      StreamController<Quote>.broadcast(sync: true);

  TickRate _rate = TickRate.defaultRate;
  int startCalls = 0;
  int pauseCalls = 0;
  Duration? lastResumeOffset;

  /// Emits a tick for [symbol] at [price].
  void tick(String symbol, Money price) {
    final next = _quotes[symbol]!.tickTo(price);
    _quotes[symbol] = next;
    _controller.add(next);
  }

  void tickRupees(String symbol, num rupees) =>
      tick(symbol, Money.fromRupees(rupees));

  @override
  Stream<Quote> get ticks => _controller.stream;

  @override
  Map<String, Quote> get snapshot => Map<String, Quote>.unmodifiable(_quotes);

  @override
  TickRate get rate => _rate;

  @override
  void setRate(TickRate rate) => _rate = rate;

  @override
  void start() => startCalls++;

  @override
  void pause() => pauseCalls++;

  @override
  void resumeAfter(Duration offline) {
    lastResumeOffset = offline;
    startCalls++;
  }

  @override
  void dispose() => _controller.close();
}
