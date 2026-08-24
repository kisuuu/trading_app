import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/features/trading/presentation/order_ticket_screen.dart';
import 'package:trading_app/src/features/watchlist/application/watchlist_controller.dart';
import 'package:trading_app/src/features/watchlist/presentation/watchlist_screen.dart';

import '../support/pump_app.dart';

/// Vertical centre of a widget, used to prove a price is rendered on the same
/// row as its symbol.
double yOf(WidgetTester tester, Finder finder) => tester.getCenter(finder).dy;

void main() {
  testWidgets('seeds a default watchlist on first launch', (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const WatchlistScreen());

    expect(find.text('My Watchlist'), findsOneWidget);
    for (final symbol in const <String>[
      'RELIANCE',
      'TCS',
      'INFY',
      'HDFCBANK',
      'ICICIBANK',
    ]) {
      expect(find.text(symbol), findsOneWidget);
    }
    expect(find.text('₹2,950.40'), findsOneWidget);
  });

  testWidgets('rows update in place as ticks arrive', (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const WatchlistScreen());

    await harness.tick(tester, 'INFY', 1900.05);

    expect(find.text('₹1,900.05'), findsOneWidget);
    expect(
      (yOf(tester, find.text('INFY')) - yOf(tester, find.text('₹1,900.05')))
          .abs(),
      lessThan(30),
      reason: 'the new price must land on the INFY row',
    );
  });

  testWidgets('reordering keeps every row bound to its own price',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const WatchlistScreen());

    final controller =
        harness.container.read(watchlistControllerProvider.notifier);
    final watchlistId =
        harness.container.read(watchlistControllerProvider).selected!.id;

    await harness.tick(tester, 'RELIANCE', 3000);
    await harness.tick(tester, 'TCS', 4200);

    final relianceBefore = yOf(tester, find.text('RELIANCE'));
    final tcsBefore = yOf(tester, find.text('TCS'));
    expect(relianceBefore, lessThan(tcsBefore));

    // Drag RELIANCE from the top down to the third slot.
    controller.reorder(watchlistId, 0, 3);
    await tester.pumpAndSettle();

    expect(yOf(tester, find.text('TCS')), lessThan(yOf(tester, find.text('RELIANCE'))));

    // The prices moved with their rows: no stale tick on the wrong symbol.
    expect(
      (yOf(tester, find.text('RELIANCE')) - yOf(tester, find.text('₹3,000.00')))
          .abs(),
      lessThan(30),
    );
    expect(
      (yOf(tester, find.text('TCS')) - yOf(tester, find.text('₹4,200.00')))
          .abs(),
      lessThan(30),
    );

    // And a tick after the reorder still finds the right row.
    await harness.tick(tester, 'RELIANCE', 3100);
    expect(
      (yOf(tester, find.text('RELIANCE')) - yOf(tester, find.text('₹3,100.00')))
          .abs(),
      lessThan(30),
    );
  });

  testWidgets('a removed stock stops updating and stays gone after a restart',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const WatchlistScreen());

    final controller =
        harness.container.read(watchlistControllerProvider.notifier);
    final watchlistId =
        harness.container.read(watchlistControllerProvider).selected!.id;

    controller.removeSymbol(watchlistId, 'TCS');
    await tester.pumpAndSettle();
    expect(find.text('TCS'), findsNothing);

    await harness.tick(tester, 'TCS', 4200);
    expect(find.text('₹4,200.00'), findsNothing);

    // Cold start against the persisted state.
    await harness.pump(tester, const WatchlistScreen());
    expect(find.text('TCS'), findsNothing);
    expect(find.text('RELIANCE'), findsOneWidget);
  });

  testWidgets('the same stock in two watchlists shows identical prices',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const WatchlistScreen());

    final controller =
        harness.container.read(watchlistControllerProvider.notifier);
    final firstId =
        harness.container.read(watchlistControllerProvider).selected!.id;

    final secondId = controller.createWatchlist('Energy');
    controller.addSymbol(secondId, 'RELIANCE');
    await tester.pumpAndSettle();

    await harness.tick(tester, 'RELIANCE', 3123.45);
    expect(find.text('Energy'), findsWidgets);
    expect(find.text('₹3,123.45'), findsOneWidget);

    // Switch back to the first list: same symbol, same notifier, same price.
    controller.select(firstId);
    await tester.pumpAndSettle();
    expect(find.text('₹3,123.45'), findsOneWidget);
  });

  testWidgets('shows an empty state for a watchlist with no stocks',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const WatchlistScreen());

    harness.container
        .read(watchlistControllerProvider.notifier)
        .createWatchlist('Empty list');
    await tester.pumpAndSettle();

    expect(find.text('Empty list is empty'), findsOneWidget);
    expect(find.text('Add stocks'), findsOneWidget);
  });

  testWidgets('tapping a row opens the ticket pre-filled with that stock',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const WatchlistScreen());

    await tester.tap(find.text('HDFCBANK'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderTicketScreen), findsOneWidget);
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('₹1,673.10'), findsOneWidget);
  });

  group('name dialog', () {
    testWidgets('cancelling leaves no disposed-controller fallout',
        (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const WatchlistScreen());

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('New watchlist'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      // Pump through the dialog's exit transition, which is when a controller
      // disposed on future-completion would blow up.
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('New watchlist'), findsNothing);
      expect(
        harness.container.read(watchlistControllerProvider).watchlists,
        hasLength(1),
      );
    });

    testWidgets('confirm is disabled until a non-blank name is typed',
        (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const WatchlistScreen());

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();

      FilledButton confirm() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'));
      expect(confirm().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(confirm().onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Banking');
      await tester.pump();
      expect(confirm().onPressed, isNotNull);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Banking'), findsWidgets);
      expect(find.text('Banking is empty'), findsOneWidget);
    });

    testWidgets('renaming pre-fills the current name and persists',
        (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const WatchlistScreen());

      await tester.tap(find.byTooltip('Watchlist options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'My Watchlist',
      );

      await tester.enterText(find.byType(TextField), 'Large caps');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Large caps'), findsWidgets);

      // Cold start: the new name came back from storage.
      await harness.pump(tester, const WatchlistScreen());
      expect(find.text('Large caps'), findsWidgets);
    });
  });
}
