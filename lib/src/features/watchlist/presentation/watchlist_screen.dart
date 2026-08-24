import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../core/widgets/empty_state.dart';
import '../../market/domain/stock.dart';
import '../../market/presentation/widgets/live_price_column.dart';
import '../application/watchlist_controller.dart';
import '../domain/watchlist.dart';
import 'widgets/stock_picker_sheet.dart';
import 'widgets/watchlist_tab_bar.dart';

enum _WatchlistAction { rename, delete }

/// Multiple named watchlists with drag-to-reorder and swipe-to-remove rows.
///
/// Rows are keyed by symbol and bind their prices by symbol, so reordering
/// moves the row *and* its price binding together — there is no index-based
/// lookup that could leave a row showing another stock's ticks mid-drag.
class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(watchlistControllerProvider);
    final controller = ref.read(watchlistControllerProvider.notifier);
    final selected = state.selected;

    return Scaffold(
      appBar: AppBar(
        title: Text(selected?.name ?? 'Watchlists'),
        actions: <Widget>[
          if (selected != null) ...<Widget>[
            IconButton(
              tooltip: 'Add stocks',
              icon: const Icon(Icons.add),
              onPressed: () =>
                  StockPickerSheet.show(context, watchlistId: selected.id),
            ),
            PopupMenuButton<_WatchlistAction>(
              tooltip: 'Watchlist options',
              onSelected: (action) =>
                  _handleAction(context, ref, selected, action),
              itemBuilder: (_) => const <PopupMenuEntry<_WatchlistAction>>[
                PopupMenuItem<_WatchlistAction>(
                  value: _WatchlistAction.rename,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Rename'),
                  ),
                ),
                PopupMenuItem<_WatchlistAction>(
                  value: _WatchlistAction.delete,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: state.isEmpty
          ? EmptyState(
              icon: Icons.playlist_add,
              title: 'No watchlists',
              message: 'Create a watchlist to start tracking stocks.',
              action: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 46),
                ),
                onPressed: () => _createWatchlist(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Create watchlist'),
              ),
            )
          : Column(
              children: <Widget>[
                WatchlistTabBar(
                  watchlists: state.watchlists,
                  selectedId: selected?.id,
                  onSelected: controller.select,
                  onCreate: () => _createWatchlist(context, ref),
                ),
                const Divider(height: 1),
                if (selected != null) ...<Widget>[
                  const MarketColumnHeader(),
                  const Divider(height: 1),
                  Expanded(
                    child: selected.isEmpty
                        ? EmptyState(
                            icon: Icons.show_chart,
                            title: '${selected.name} is empty',
                            message:
                                'Add stocks to see their live prices here.',
                            action: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(200, 46),
                              ),
                              onPressed: () => StockPickerSheet.show(
                                context,
                                watchlistId: selected.id,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add stocks'),
                            ),
                          )
                        : _WatchlistRows(watchlist: selected),
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _createWatchlist(BuildContext context, WidgetRef ref) async {
    final name = await promptWatchlistName(
      context,
      title: 'New watchlist',
      confirmLabel: 'Create',
    );
    if (name == null || name.trim().isEmpty) return;
    ref.read(watchlistControllerProvider.notifier).createWatchlist(name);
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    Watchlist watchlist,
    _WatchlistAction action,
  ) async {
    final controller = ref.read(watchlistControllerProvider.notifier);
    switch (action) {
      case _WatchlistAction.rename:
        final name = await promptWatchlistName(
          context,
          title: 'Rename watchlist',
          confirmLabel: 'Save',
          initialValue: watchlist.name,
        );
        if (name == null || name.trim().isEmpty) return;
        controller.renameWatchlist(watchlist.id, name);
      case _WatchlistAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete "${watchlist.name}"?'),
            content: const Text(
              'The watchlist and its stocks will be removed. '
              'Your holdings are not affected.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) controller.deleteWatchlist(watchlist.id);
    }
  }
}

class _WatchlistRows extends ConsumerWidget {
  const _WatchlistRows({required this.watchlist});

  final Watchlist watchlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(watchlistControllerProvider.notifier);

    return ReorderableListView.builder(
      // Explicit handles: the row itself stays tappable for the order ticket,
      // and the drag affordance is visible rather than hidden behind a
      // long-press the user has to discover.
      buildDefaultDragHandles: false,
      itemCount: watchlist.symbols.length,
      onReorder: (oldIndex, newIndex) =>
          controller.reorder(watchlist.id, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        elevation: 6,
        child: child,
      ),
      itemBuilder: (context, index) {
        final symbol = watchlist.symbols[index];
        return _WatchlistRow(
          // Keyed by symbol, not index: the framework then moves the existing
          // element (and its running flash animation) instead of rebuilding a
          // different symbol into the same slot.
          key: ValueKey<String>('${watchlist.id}:$symbol'),
          watchlistId: watchlist.id,
          symbol: symbol,
          index: index,
        );
      },
    );
  }
}

class _WatchlistRow extends ConsumerWidget {
  const _WatchlistRow({
    required this.watchlistId,
    required this.symbol,
    required this.index,
    super.key,
  });

  final String watchlistId;
  final String symbol;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey<String>('dismiss:$watchlistId:$symbol'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        color: theme.colorScheme.errorContainer,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => _remove(context, ref),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor),
          ),
        ),
        child: InkWell(
          onTap: () => AppNavigator.openTicket(context, symbol: symbol),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SymbolIdentity(
                    symbol: symbol,
                    name: StockUniverse.nameOf(symbol),
                  ),
                ),
                LivePriceColumn(symbol: symbol),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _remove(BuildContext context, WidgetRef ref) {
    final controller = ref.read(watchlistControllerProvider.notifier);
    controller.removeSymbol(watchlistId, symbol);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$symbol removed'),
          action: SnackBarAction(
            label: 'Undo',
            // Restores at the original position rather than appending.
            onPressed: () =>
                controller.insertSymbol(watchlistId, symbol, index),
          ),
        ),
      );
  }
}
