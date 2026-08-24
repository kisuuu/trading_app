import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/features/market/domain/stock.dart';
import 'package:trading_app/src/features/market/presentation/market_screen.dart';

import '../support/pump_app.dart';

void main() {
  testWidgets('lists every stock in the universe', (tester) async {
    await AppHarness().pump(tester, const MarketScreen());

    for (final stock in StockUniverse.stocks) {
      expect(find.text(stock.symbol), findsOneWidget);
    }
  });

  testWidgets('opens at the previous close, then updates in place on a tick',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const MarketScreen());

    expect(find.text('₹2,950.40'), findsOneWidget);

    harness.feed.tickRupees('RELIANCE', 2975.15);
    await tester.pump();
    await tester.pump(); // the coalesced flush lands on the following frame

    expect(find.text('₹2,975.15'), findsOneWidget);
    expect(find.text('₹2,950.40'), findsNothing);
    // The row moved its price, it did not duplicate or disappear.
    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.text('+₹24.75  (+0.84%)'), findsOneWidget);
  });

  testWidgets('a tick on one symbol leaves the others untouched',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const MarketScreen());

    harness.feed.tickRupees('TCS', 4200);
    await tester.pump();
    await tester.pump();

    expect(find.text('₹4,200.00'), findsOneWidget);
    expect(find.text('₹2,950.40'), findsOneWidget); // RELIANCE, unchanged
  });

  testWidgets('shows a down move with the right sign', (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const MarketScreen());

    harness.feed.tickRupees('INFY', 1850);
    await tester.pump();
    await tester.pump();

    expect(find.text('-₹15.25  (-0.82%)'), findsOneWidget);
  });

  testWidgets('stays responsive while a burst of ticks arrives',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const MarketScreen());

    // 250 ticks — one second at the stress rate — between two frames.
    for (var i = 0; i < 25; i++) {
      for (final stock in StockUniverse.stocks) {
        harness.feed.tickRupees(
          stock.symbol,
          stock.previousClose.asRupees + i * 0.1,
        );
      }
    }
    await tester.pump();
    await tester.pump();

    // Only the final price of the burst is ever rendered.
    expect(find.text('₹2,952.80'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
