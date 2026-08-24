import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/scheduler/frame_scheduler.dart';
import '../data/market_feed.dart';
import '../domain/quote.dart';
import '../domain/stock.dart';

/// The app's single source of price truth.
///
/// Everything price-related — the market screen, every watchlist row, the order
/// ticket, holdings and the portfolio summary — reads from the *same*
/// [ValueListenable] instance per symbol. Two watchlists containing RELIANCE
/// are not two subscriptions that could diverge; they are two widgets listening
/// to one notifier, so identical prices are structural rather than something
/// that has to be kept in sync.
///
/// ## Why this is not a `StreamProvider` per symbol
///
/// Ticks arrive far faster than frames. Under [TickRate.stress] the feed emits
/// ~250 updates/sec across the universe. Rebuilding on every one would queue
/// four times more work than a 60 Hz display can retire.
///
/// So ticks are *absorbed*, not forwarded: each one overwrites a pending entry
/// in a dirty map and asks the [FrameScheduler] for a flush. At most one flush
/// happens per frame, and it touches only the symbols that actually moved.
/// Raising the tick rate therefore raises feed CPU but leaves UI work flat —
/// intermediate prices nobody could have seen are dropped rather than rendered.
class MarketDataService {
  MarketDataService({
    required MarketFeed feed,
    FrameScheduler? scheduler,
    List<Stock> universe = StockUniverse.stocks,
  })  : _feed = feed,
        _scheduler = scheduler ?? WidgetsFrameScheduler() {
    final snapshot = feed.snapshot;
    for (final stock in universe) {
      _quotes[stock.symbol] = ValueNotifier<Quote>(
        snapshot[stock.symbol] ??
            Quote.initial(
              symbol: stock.symbol,
              previousClose: stock.previousClose,
            ),
      );
    }
    _subscription = feed.ticks.listen(_onTick);
    feed.start();
  }

  final MarketFeed _feed;
  final FrameScheduler _scheduler;

  final Map<String, ValueNotifier<Quote>> _quotes =
      <String, ValueNotifier<Quote>>{};

  /// Ticks received since the last flush, keyed by symbol. A symbol that ticks
  /// ten times within one frame is written ten times and read once.
  final Map<String, Quote> _pending = <String, Quote>{};

  /// Bumped once per flush. Widgets that depend on *many* symbols at once —
  /// the portfolio summary, the P&L sort order — listen here instead of
  /// subscribing to ten notifiers and rebuilding ten times per frame.
  final ValueNotifier<int> _epoch = ValueNotifier<int>(0);

  StreamSubscription<Quote>? _subscription;
  DateTime? _pausedAt;
  bool _disposed = false;

  /// Diagnostics for the debug panel: how many raw ticks the feed produced and
  /// how many UI flushes that turned into.
  int _ticksReceived = 0;
  int _flushCount = 0;

  int get ticksReceived => _ticksReceived;

  int get flushCount => _flushCount;

  ValueListenable<int> get epoch => _epoch;

  TickRate get rate => _feed.rate;

  void setRate(TickRate rate) => _feed.setRate(rate);

  /// The live notifier for [symbol]. Stable for the lifetime of the service, so
  /// callers can hold onto it across rebuilds and reorders.
  ValueListenable<Quote> quoteListenable(String symbol) {
    final notifier = _quotes[symbol];
    if (notifier == null) {
      throw ArgumentError.value(symbol, 'symbol', 'Not in the market universe');
    }
    return notifier;
  }

  /// Current price snapshot for [symbol], read synchronously.
  ///
  /// Returns `null` for unknown symbols so callers restoring persisted data can
  /// skip stale entries instead of throwing.
  Quote? quoteOrNull(String symbol) => _quotes[symbol]?.value;

  Quote quote(String symbol) {
    final quote = quoteOrNull(symbol);
    if (quote == null) {
      throw ArgumentError.value(symbol, 'symbol', 'Not in the market universe');
    }
    return quote;
  }

  /// Called when the app is backgrounded: stop burning CPU on prices nobody can
  /// see.
  void onAppPaused() {
    _pausedAt = DateTime.now();
    _feed.pause();
  }

  /// Called when the app returns to the foreground. The feed rolls its walk
  /// forward by however long we were away, so the user comes back to a market
  /// that moved rather than to prices frozen at the moment they left.
  void onAppResumed() {
    final pausedAt = _pausedAt;
    _pausedAt = null;
    _feed.resumeAfter(
      pausedAt == null ? Duration.zero : DateTime.now().difference(pausedAt),
    );
  }

  void _onTick(Quote quote) {
    if (_disposed) return;
    _ticksReceived++;
    // Last write wins: only the newest price within this frame survives.
    _pending[quote.symbol] = quote;
    _scheduler.schedule(_flush);
  }

  /// Applies every pending tick in one pass, then bumps the epoch.
  ///
  /// Because all notifiers are written before the epoch fires, aggregate
  /// listeners always observe a consistent set of prices — the portfolio
  /// summary can never show a total computed from a half-updated frame.
  void _flush() {
    if (_disposed || _pending.isEmpty) return;
    _flushCount++;
    for (final entry in _pending.entries) {
      _quotes[entry.key]?.value = entry.value;
    }
    _pending.clear();
    _epoch.value++;
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _scheduler.dispose();
    _feed.dispose();
    for (final notifier in _quotes.values) {
      notifier.dispose();
    }
    _epoch.dispose();
  }
}
