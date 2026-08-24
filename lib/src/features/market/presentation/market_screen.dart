import 'package:flutter/material.dart';

import '../../../app/navigation.dart';
import '../domain/stock.dart';
import 'widgets/feed_settings_sheet.dart';
import 'widgets/live_price_column.dart';

/// Live market overview for the full universe.
///
/// The list itself is built once. Each row's price block subscribes to its own
/// symbol, so a tick repaints one cell rather than invalidating the list — the
/// reason scrolling stays smooth even at stress tick rates.
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market'),
        actions: <Widget>[
          IconButton(
            onPressed: () => FeedSettingsSheet.show(context),
            icon: const Icon(Icons.speed_outlined),
            tooltip: 'Feed settings',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const MarketColumnHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              // Prices update in place; rows are never inserted or removed, so
              // the list structure is stable for the whole session.
              itemCount: StockUniverse.stocks.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final stock = StockUniverse.stocks[index];
                return _MarketRow(
                  key: ValueKey<String>(stock.symbol),
                  symbol: stock.symbol,
                  name: stock.name,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketRow extends StatelessWidget {
  const _MarketRow({required this.symbol, required this.name, super.key});

  final String symbol;
  final String name;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => AppNavigator.openTicket(context, symbol: symbol),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: <Widget>[
            Expanded(child: SymbolIdentity(symbol: symbol, name: name)),
            LivePriceColumn(symbol: symbol),
          ],
        ),
      ),
    );
  }
}
