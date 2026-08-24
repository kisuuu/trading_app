import 'package:meta/meta.dart';

import '../../../core/money/money.dart';

/// Direction of the most recent tick — drives the row flash colour.
enum TickDirection { up, down, unchanged }

/// An immutable snapshot of a symbol's market state.
///
/// Quotes are replaced wholesale on each tick rather than mutated, so a widget
/// holding an old quote can never observe a half-updated price.
@immutable
class Quote {
  const Quote({
    required this.symbol,
    required this.ltp,
    required this.previousClose,
    required this.direction,
    required this.sequence,
  });

  /// The opening snapshot for a symbol: last traded price starts at the
  /// previous close with no tick direction yet.
  factory Quote.initial({required String symbol, required Money previousClose}) {
    return Quote(
      symbol: symbol,
      ltp: previousClose,
      previousClose: previousClose,
      direction: TickDirection.unchanged,
      sequence: 0,
    );
  }

  final String symbol;

  /// Last traded price.
  final Money ltp;

  final Money previousClose;

  final TickDirection direction;

  /// Monotonic per-symbol counter. Lets the UI tell "same price, new tick"
  /// apart from "no tick at all", so a flash still fires on a flat re-trade,
  /// and makes out-of-order updates detectable.
  final int sequence;

  /// Absolute change against the previous close.
  Money get change => ltp - previousClose;

  /// Percentage change against the previous close.
  double get changePercent => change.percentOf(previousClose);

  bool get isUp => change.isPositive;

  bool get isDown => change.isNegative;

  /// Produces the next quote at [price], deriving the tick direction from the
  /// move relative to this quote.
  Quote tickTo(Money price) {
    return Quote(
      symbol: symbol,
      ltp: price,
      previousClose: previousClose,
      direction: switch (price.compareTo(ltp)) {
        > 0 => TickDirection.up,
        < 0 => TickDirection.down,
        _ => TickDirection.unchanged,
      },
      sequence: sequence + 1,
    );
  }

  @override
  String toString() => 'Quote($symbol, ltp: $ltp, seq: $sequence)';
}
