import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/app/theme.dart';
import 'package:trading_app/src/core/persistence/key_value_store.dart';
import 'package:trading_app/src/core/persistence/store_provider.dart';
import 'package:trading_app/src/features/market/application/market_providers.dart';

import 'fake_market_feed.dart';

/// Harness for widget tests: real widgets and real providers, with storage and
/// the market feed swapped for deterministic doubles.
///
/// The [store] survives between [pump] calls, so pumping a second screen with
/// the same harness reproduces an app restart against the data the first screen
/// wrote.
class AppHarness {
  AppHarness({KeyValueStore? store})
      : store = store ?? InMemoryKeyValueStore(),
        feed = FakeMarketFeed();

  final KeyValueStore store;
  final FakeMarketFeed feed;

  ProviderContainer? _container;
  int _generation = 0;

  /// Direct provider access, for driving controllers from a test.
  ProviderContainer get container =>
      _container ?? (throw StateError('pump() first'));

  /// Pumps [child] on a tall surface so lazily-built list rows are all laid
  /// out — otherwise off-screen rows simply do not exist to find.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size surfaceSize = const Size(420, 1600),
  }) async {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    _container?.dispose();
    final container = ProviderContainer(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(store),
        marketFeedProvider.overrideWithValue(feed),
      ],
    );
    _container = container;
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // A fresh key remounts the whole tree — including the Navigator and
        // its route stack — so a second pump really is a cold start.
        child: MaterialApp(
          key: ValueKey<int>(_generation++),
          theme: AppTheme.dark(),
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Emits a tick and lets the coalesced flush reach the widget tree.
  Future<void> tick(WidgetTester tester, String symbol, num rupees) async {
    feed.tickRupees(symbol, rupees);
    await tester.pump(); // runs the scheduled post-frame flush
    await tester.pump(); // rebuilds the notified subtrees
  }
}
