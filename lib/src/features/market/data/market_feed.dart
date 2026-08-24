import '../domain/quote.dart';

/// Tick rates the feed can run at, exposed as a debug setting.
///
/// [stress] exists to demonstrate the coalescing pipeline: 25 ticks/sec across
/// 10 symbols is 250 updates/sec, well past what any display can show.
enum TickRate {
  calm('Calm', 1),
  normal('Normal', 4),
  fast('Fast', 10),
  stress('Stress', 25);

  const TickRate(this.label, this.ticksPerSecondPerSymbol);

  final String label;
  final int ticksPerSecondPerSymbol;

  /// Aggregate feed throughput across the whole universe.
  int totalTicksPerSecond(int symbolCount) =>
      ticksPerSecondPerSymbol * symbolCount;

  static const TickRate defaultRate = TickRate.normal;
}

/// Source of market data.
///
/// The app depends on this interface rather than the mock implementation, so
/// swapping in a real websocket feed later is a one-line provider change.
abstract interface class MarketFeed {
  /// Continuous stream of price updates. Broadcast: many listeners, no replay.
  Stream<Quote> get ticks;

  /// Latest known quote for every symbol, available synchronously so a screen
  /// opened mid-session paints real prices on its first frame instead of
  /// flashing placeholders.
  Map<String, Quote> get snapshot;

  TickRate get rate;

  void setRate(TickRate rate);

  void start();

  void pause();

  /// Simulates the market having moved while the app was backgrounded, so the
  /// user never returns to a visibly frozen price.
  void resumeAfter(Duration offline);

  void dispose();
}
