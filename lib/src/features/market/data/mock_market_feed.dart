import 'dart:async';
import 'dart:math';

import '../../../core/money/money.dart';
import '../domain/quote.dart';
import '../domain/stock.dart';
import 'market_feed.dart';

/// In-process mock market data feed.
///
/// Prices follow a mean-reverting random walk: each tick applies a Gaussian
/// shock scaled by the symbol's volatility, plus a gentle pull back toward the
/// previous close. That keeps the tape lively without letting a symbol drift to
/// an absurd price over a long session, and it is bounded by a ±20% circuit
/// band the way a real exchange would be.
///
/// The engine runs on a fixed 25 ms timer regardless of the configured rate.
/// Per fire, each symbol receives `rate × 0.025` ticks — a whole number plus a
/// Bernoulli draw for the remainder. This staggers arrivals (symbols do not all
/// tick in lockstep, which would look synthetic) and keeps timer pressure
/// constant as the rate is dialled from 1 to 25 ticks/sec/symbol.
class MockMarketFeed implements MarketFeed {
  MockMarketFeed({
    List<Stock> universe = StockUniverse.stocks,
    TickRate rate = TickRate.defaultRate,
    Random? random,
  })  : _universe = universe,
        _rate = rate,
        _random = random ?? Random(),
        _quotes = <String, Quote>{
          for (final stock in universe)
            stock.symbol: Quote.initial(
              symbol: stock.symbol,
              previousClose: stock.previousClose,
            ),
        };

  /// How often the generator wakes up. Decoupled from the configured tick rate.
  static const Duration engineInterval = Duration(milliseconds: 25);

  /// Circuit band: prices stay within ±20% of the previous close.
  static const double _circuitBand = 0.20;

  final List<Stock> _universe;
  final Random _random;
  final Map<String, Quote> _quotes;
  final StreamController<Quote> _controller =
      StreamController<Quote>.broadcast(sync: true);

  Timer? _timer;
  TickRate _rate;
  bool _disposed = false;

  /// Cached second sample from Box–Muller, which produces normals in pairs.
  double? _spareGaussian;

  @override
  Stream<Quote> get ticks => _controller.stream;

  @override
  Map<String, Quote> get snapshot => Map<String, Quote>.unmodifiable(_quotes);

  @override
  TickRate get rate => _rate;

  @override
  void setRate(TickRate rate) {
    if (_rate == rate) return;
    _rate = rate;
  }

  @override
  void start() {
    if (_disposed || _timer != null) return;
    _timer = Timer.periodic(engineInterval, (_) => _onEngineTick());
  }

  @override
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void resumeAfter(Duration offline) {
    if (_disposed) return;
    // Roll the walk forward for the time we were away, capped so a device left
    // asleep overnight does not produce a single absurd gap.
    final missedPerSymbol = min(
      (offline.inMilliseconds / 1000 * _rate.ticksPerSecondPerSymbol).round(),
      600,
    );
    if (missedPerSymbol > 0) {
      for (final stock in _universe) {
        var quote = _quotes[stock.symbol]!;
        for (var i = 0; i < missedPerSymbol; i++) {
          quote = quote.tickTo(_nextPrice(stock, quote.ltp));
        }
        _quotes[stock.symbol] = quote;
        _controller.add(quote);
      }
    }
    start();
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    _controller.close();
  }

  void _onEngineTick() {
    final ticksPerSymbol = _rate.ticksPerSecondPerSymbol *
        engineInterval.inMilliseconds /
        Duration.millisecondsPerSecond;
    final whole = ticksPerSymbol.floor();
    final fractional = ticksPerSymbol - whole;

    for (final stock in _universe) {
      // Whole part plus a coin flip weighted by the remainder: over time this
      // averages out to exactly the configured rate, with natural jitter.
      final count = whole + (_random.nextDouble() < fractional ? 1 : 0);
      for (var i = 0; i < count; i++) {
        _emit(stock);
      }
    }
  }

  void _emit(Stock stock) {
    final current = _quotes[stock.symbol]!;
    final next = current.tickTo(_nextPrice(stock, current.ltp));
    _quotes[stock.symbol] = next;
    _controller.add(next);
  }

  /// One step of the mean-reverting random walk, in exact paise.
  Money _nextPrice(Stock stock, Money current) {
    final anchor = stock.previousClose.paise;
    final currentPaise = current.paise;

    final shock = _gaussian() * stock.volatilityBps / 10000 * currentPaise;
    final reversion = (anchor - currentPaise) * 0.004;

    var nextPaise = (currentPaise + shock + reversion).round();

    // Guarantee a visible move: a tick that rounds to no change at all reads as
    // a frozen feed, so nudge it by a paisa in the shock's direction.
    if (nextPaise == currentPaise) {
      nextPaise += shock.isNegative ? -1 : 1;
    }

    final lowerBound = (anchor * (1 - _circuitBand)).round();
    final upperBound = (anchor * (1 + _circuitBand)).round();
    return Money(nextPaise.clamp(lowerBound, upperBound));
  }

  /// Standard normal sample via the Box–Muller transform.
  double _gaussian() {
    final spare = _spareGaussian;
    if (spare != null) {
      _spareGaussian = null;
      return spare;
    }
    // `nextDouble()` can return 0, which log() rejects; nudge off the boundary.
    final u1 = max(_random.nextDouble(), 1e-12);
    final u2 = _random.nextDouble();
    final magnitude = sqrt(-2 * log(u1));
    _spareGaussian = magnitude * sin(2 * pi * u2);
    return magnitude * cos(2 * pi * u2);
  }
}
