import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/market_providers.dart';
import '../../domain/quote.dart';

/// Binds a subtree to one symbol's live quote.
///
/// Two properties matter here:
///
/// * **Binding is by symbol, never by list index.** Reordering a watchlist
///   changes indices but not this widget's `symbol`, so a row can never end up
///   rendering another row's ticks.
/// * **The rebuild is contained.** The provider read happens once; only the
///   `ValueListenableBuilder`'s subtree rebuilds on a tick, so surrounding
///   layout, list plumbing and non-price content are untouched.
class QuoteBuilder extends ConsumerWidget {
  const QuoteBuilder({
    required this.symbol,
    required this.builder,
    this.child,
    super.key,
  });

  final String symbol;

  final ValueWidgetBuilder<Quote> builder;

  /// Subtree that does not depend on the quote; passed through untouched so it
  /// is built once rather than on every tick.
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(marketDataServiceProvider);
    return ValueListenableBuilder<Quote>(
      valueListenable: market.quoteListenable(symbol),
      builder: builder,
      child: child,
    );
  }
}
