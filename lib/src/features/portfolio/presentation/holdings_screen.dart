import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/widgets/empty_state.dart';
import '../../market/presentation/widgets/live_price_column.dart';
import '../../trading/presentation/orders_screen.dart';
import '../application/holdings_sort.dart';
import '../application/portfolio_controller.dart';
import 'widgets/holding_row.dart';
import 'widgets/portfolio_summary_card.dart';

/// Portfolio view: aggregate P&L on top, one live row per position.
class HoldingsScreen extends ConsumerWidget {
  const HoldingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holdings'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Order history',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const OrdersScreen()),
            ),
          ),
        ],
      ),
      body: holdings.isEmpty
          ? const Column(
              children: <Widget>[
                PortfolioSummaryCard(),
                Expanded(
                  child: EmptyState(
                    icon: Icons.pie_chart_outline,
                    title: 'No holdings yet',
                    message:
                        'Buy a stock from the Market or a watchlist and your '
                        'position will show up here with live P&L.',
                  ),
                ),
              ],
            )
          : const Column(
              children: <Widget>[
                PortfolioSummaryCard(),
                _SortBar(),
                Divider(height: 1),
                MarketColumnHeader(
                  leading: 'SYMBOL · QTY @ AVG',
                  trailing: 'VALUE · LTP · P&L',
                ),
                Divider(height: 1),
                Expanded(child: _HoldingsList()),
              ],
            ),
    );
  }
}

class _SortBar extends ConsumerWidget {
  const _SortBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(holdingsSortProvider);
    final count = ref.watch(holdingsProvider).length;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 6),
      child: Row(
        children: <Widget>[
          Text(
            '$count position${count == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          PopupMenuButton<HoldingsSort>(
            initialValue: sort,
            tooltip: 'Sort holdings',
            onSelected: ref.read(holdingsSortProvider.notifier).set,
            itemBuilder: (_) => <PopupMenuEntry<HoldingsSort>>[
              for (final option in HoldingsSort.values)
                PopupMenuItem<HoldingsSort>(
                  value: option,
                  child: Text(option.label),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.swap_vert, size: 18),
                  const SizedBox(width: 4),
                  Text(sort.label, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The list is driven by the published sort order, not rebuilt per tick.
///
/// [HoldingsOrderNotifier] re-evaluates the ordering on every flush but only
/// notifies when the sequence genuinely changes — so a position crossing from
/// loss to gain animates into its new place, while ordinary ticks only repaint
/// the numbers inside each row.
class _HoldingsList extends ConsumerWidget {
  const _HoldingsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(holdingsOrderProvider);
    final portfolio = ref.watch(portfolioControllerProvider);

    return ValueListenableBuilder<List<String>>(
      valueListenable: order,
      builder: (context, symbols, _) {
        return ListView.separated(
          itemCount: symbols.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
          itemBuilder: (context, index) {
            final holding = portfolio.holdingOf(symbols[index]);
            // Defensive: the order list is recomputed from the same portfolio,
            // but a rebuild racing a sell should render nothing rather than
            // throw.
            if (holding == null) return const SizedBox.shrink();
            return HoldingRow(
              key: ValueKey<String>(holding.symbol),
              holding: holding,
              onTap: () =>
                  AppNavigator.openTicket(context, symbol: holding.symbol),
            );
          },
        );
      },
    );
  }
}
