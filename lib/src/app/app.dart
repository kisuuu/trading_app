import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/market/application/market_providers.dart';
import 'home_shell.dart';
import 'theme.dart';

/// Root widget.
///
/// Also owns the feed's lifecycle: the generator is stopped while the app is in
/// the background and rolled forward on resume, so the user never comes back to
/// a market that stood still — without burning CPU on prices nobody can see.
class TradingApp extends ConsumerStatefulWidget {
  const TradingApp({super.key});

  @override
  ConsumerState<TradingApp> createState() => _TradingAppState();
}

class _TradingAppState extends ConsumerState<TradingApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Instantiate the service eagerly so ticks start flowing before the first
    // screen is built, rather than on whichever widget happens to read it.
    ref.read(marketDataServiceProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final market = ref.read(marketDataServiceProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        market.onAppResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        market.onAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trading',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}
