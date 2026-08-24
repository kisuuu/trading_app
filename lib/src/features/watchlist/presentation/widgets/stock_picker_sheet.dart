import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../market/domain/stock.dart';
import '../../../market/presentation/widgets/live_price_column.dart';
import '../../application/watchlist_controller.dart';

/// Picker over the fixed universe, with live prices so the user can decide
/// while looking at the market rather than from memory.
///
/// Toggling is applied immediately: the sheet stays open so several stocks can
/// be added in one pass, and the underlying watchlist updates behind it.
class StockPickerSheet extends ConsumerWidget {
  const StockPickerSheet({required this.watchlistId, super.key});

  final String watchlistId;

  static Future<void> show(BuildContext context, {required String watchlistId}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StockPickerSheet(watchlistId: watchlistId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(watchlistControllerProvider);
    final watchlist = state.byId(watchlistId);

    if (watchlist == null) {
      return const SizedBox(height: 120, child: Center(child: Text('Watchlist not found')));
    }

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Add to ${watchlist.name}', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${watchlist.length} of ${StockUniverse.stocks.length} added',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: StockUniverse.stocks.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final stock = StockUniverse.stocks[index];
                final isAdded = watchlist.contains(stock.symbol);
                return InkWell(
                  onTap: () => ref
                      .read(watchlistControllerProvider.notifier)
                      .toggleSymbol(watchlistId, stock.symbol),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          isAdded
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          size: 22,
                          color: isAdded
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SymbolIdentity(
                            symbol: stock.symbol,
                            name: stock.name,
                          ),
                        ),
                        LivePriceColumn(symbol: stock.symbol),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
