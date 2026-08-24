import 'package:flutter/material.dart';

import '../features/market/presentation/market_screen.dart';
import '../features/portfolio/presentation/holdings_screen.dart';
import '../features/watchlist/presentation/watchlist_screen.dart';

/// Bottom-navigation shell.
///
/// Uses an [IndexedStack] so each tab keeps its scroll position and its live
/// price subscriptions while hidden. Returning to a tab shows current prices
/// immediately — the feed never stopped, and the notifiers already hold the
/// latest values, so there is no refetch and no stale first frame.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _tabs = <Widget>[
    WatchlistScreen(),
    MarketScreen(),
    HoldingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined),
            selectedIcon: Icon(Icons.candlestick_chart),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Holdings',
          ),
        ],
      ),
    );
  }
}
