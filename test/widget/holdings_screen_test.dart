import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/core/money/money.dart';
import 'package:trading_app/src/core/persistence/key_value_store.dart';
import 'package:trading_app/src/features/portfolio/data/portfolio_repository.dart';
import 'package:trading_app/src/features/portfolio/domain/holding.dart';
import 'package:trading_app/src/features/portfolio/domain/portfolio.dart';
import 'package:trading_app/src/features/portfolio/presentation/holdings_screen.dart';
import 'package:trading_app/src/features/trading/presentation/order_ticket_screen.dart';

import '../support/pump_app.dart';

/// 10 RELIANCE at its previous close, 5 TCS at its previous close.
const Portfolio seeded = Portfolio(
  cash: Money(94986100),
  holdings: <String, Holding>{
    'RELIANCE': Holding(
      symbol: 'RELIANCE',
      quantity: 10,
      totalCost: Money(2950400),
    ),
    'TCS': Holding(symbol: 'TCS', quantity: 5, totalCost: Money(2062900)),
  },
);

Future<AppHarness> seededHarness(WidgetTester tester) async {
  final store = InMemoryKeyValueStore();
  await PortfolioRepository(store).save(seeded);
  final harness = AppHarness(store: store);
  await harness.pump(tester, const HoldingsScreen());
  return harness;
}

double yOf(WidgetTester tester, Finder finder) => tester.getCenter(finder).dy;

void main() {
  testWidgets('shows an empty state when nothing is held', (tester) async {
    await AppHarness().pump(tester, const HoldingsScreen());

    expect(find.text('No holdings yet'), findsOneWidget);
    expect(find.text('+₹0.00'), findsOneWidget); // summary still renders
  });

  testWidgets('restores holdings after a restart with quantity and avg cost',
      (tester) async {
    await seededHarness(tester);

    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.text('10 @ ₹2,950.40'), findsOneWidget);
    expect(find.text('TCS'), findsOneWidget);
    expect(find.text('5 @ ₹4,125.80'), findsOneWidget);
    expect(find.text('2 positions'), findsOneWidget);
  });

  testWidgets('P&L updates live and the summary equals the sum of rows',
      (tester) async {
    final harness = await seededHarness(tester);

    await harness.tick(tester, 'RELIANCE', 3000);
    await harness.tick(tester, 'TCS', 4200);

    // Row figures: value, LTP and P&L.
    expect(find.text('₹30,000.00'), findsOneWidget);
    expect(find.text('LTP ₹3,000.00'), findsOneWidget);
    expect(find.text('+₹496.00'), findsOneWidget);

    expect(find.text('₹21,000.00'), findsOneWidget);
    expect(find.text('+₹371.00'), findsOneWidget);

    // Aggregate: 496.00 + 371.00 = 867.00 on 50,133.00 invested.
    expect(find.text('+₹867.00'), findsOneWidget);
    expect(find.text('₹50,133.00'), findsOneWidget);
    expect(find.text('₹51,000.00'), findsOneWidget);
    expect(find.text('+1.73%'), findsOneWidget);
  });

  testWidgets('shows a loss in the negative direction', (tester) async {
    final harness = await seededHarness(tester);

    await harness.tick(tester, 'RELIANCE', 2900);

    // Once on the RELIANCE row, once in the summary — TCS is flat, so the
    // aggregate is exactly this one row's loss.
    expect(find.text('-₹504.00'), findsNWidgets(2));
    expect(find.text('-1.71%'), findsOneWidget); // row percent
  });

  testWidgets('re-sorts when a position overtakes another on P&L',
      (tester) async {
    final harness = await seededHarness(tester);

    await harness.tick(tester, 'RELIANCE', 3000); // +496.00
    await harness.tick(tester, 'TCS', 4200); // +371.00

    expect(
      yOf(tester, find.text('RELIANCE')),
      lessThan(yOf(tester, find.text('TCS'))),
    );

    await harness.tick(tester, 'TCS', 4500); // +1,871.00 — now the leader
    await tester.pumpAndSettle();

    expect(
      yOf(tester, find.text('TCS')),
      lessThan(yOf(tester, find.text('RELIANCE'))),
    );
  });

  testWidgets('tapping a holding opens the ticket for that stock',
      (tester) async {
    await seededHarness(tester);

    await tester.tap(find.text('TCS'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderTicketScreen), findsOneWidget);
    expect(find.text('Tata Consultancy Services'), findsOneWidget);
  });
}
