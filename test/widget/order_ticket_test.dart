import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/core/money/money.dart';
import 'package:trading_app/src/features/portfolio/application/portfolio_controller.dart';
import 'package:trading_app/src/features/portfolio/domain/portfolio.dart';
import 'package:trading_app/src/features/portfolio/presentation/holdings_screen.dart';
import 'package:trading_app/src/features/trading/application/trading_controller.dart';
import 'package:trading_app/src/features/trading/domain/trade_order.dart';
import 'package:trading_app/src/features/trading/presentation/order_ticket_screen.dart';

import '../support/pump_app.dart';

Finder submitButton() => find.byType(FilledButton);

bool isEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(submitButton()).onPressed != null;

void main() {
  testWidgets('opens pre-filled with the stock and its live price',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(
      tester,
      const OrderTicketScreen(symbol: 'RELIANCE'),
    );

    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.text('Reliance Industries'), findsOneWidget);
    expect(find.text('₹2,950.40'), findsOneWidget);
  });

  testWidgets('order value tracks both the typed quantity and live ticks',
      (tester) async {
    final harness = AppHarness();
    await harness.pump(tester, const OrderTicketScreen(symbol: 'RELIANCE'));

    await tester.enterText(find.byType(TextField), '10');
    await tester.pump();
    expect(find.text('₹29,504.00'), findsOneWidget);

    await harness.tick(tester, 'RELIANCE', 3000);

    expect(find.text('₹30,000.00'), findsOneWidget); // new order value
    expect(find.text('₹29,504.00'), findsNothing);
  });

  group('validation', () {
    testWidgets('blocks submit until a quantity is entered', (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const OrderTicketScreen(symbol: 'RELIANCE'));
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('blocks a fractional quantity with an explanation',
        (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const OrderTicketScreen(symbol: 'RELIANCE'));

      await tester.enterText(find.byType(TextField), '2.5');
      await tester.pump();

      expect(find.textContaining('Fractional quantities'), findsOneWidget);
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('blocks zero and negative quantities', (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const OrderTicketScreen(symbol: 'RELIANCE'));

      for (final input in <String>['0', '-5']) {
        await tester.enterText(find.byType(TextField), input);
        await tester.pump();
        expect(find.text('Quantity must be at least 1'), findsOneWidget);
        expect(isEnabled(tester), isFalse);
      }
    });

    testWidgets('blocks a buy larger than the available balance',
        (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const OrderTicketScreen(symbol: 'RELIANCE'));

      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();

      expect(
        find.textContaining('exceeds your available balance'),
        findsOneWidget,
      );
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('blocks a sell of more shares than are held', (tester) async {
      final harness = AppHarness();
      await harness.pump(
        tester,
        const OrderTicketScreen(
          symbol: 'RELIANCE',
          initialSide: OrderSide.sell,
        ),
      );

      await tester.enterText(find.byType(TextField), '5');
      await tester.pump();

      expect(
        find.textContaining('do not hold any shares'),
        findsOneWidget,
      );
      expect(isEnabled(tester), isFalse);
    });
  });

  group('execution', () {
    testWidgets('fills at the LTP at submission, not at form-open time',
        (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const OrderTicketScreen(symbol: 'RELIANCE'));

      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();

      // The price moves after the form was filled in.
      await harness.tick(tester, 'RELIANCE', 2960.50);

      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(find.text('Order placed'), findsOneWidget);
      expect(find.text('BUY 10 RELIANCE'), findsOneWidget);
      expect(find.text('Executed at ₹2,960.50 per share'), findsOneWidget);
      expect(find.text('₹29,605.00'), findsOneWidget); // order value

      final portfolio = harness.container.read(portfolioControllerProvider);
      expect(portfolio.cash, Portfolio.openingCash - const Money(2960500));
      expect(portfolio.quantityHeld('RELIANCE'), 10);
      expect(
        harness.container.read(orderHistoryProvider).single.price,
        const Money(296050),
      );
    });

    testWidgets('the filled position survives a restart', (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const OrderTicketScreen(symbol: 'RELIANCE'));

      await tester.enterText(find.byType(TextField), '4');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      // Re-pump against the same store: a fresh provider container reading
      // persisted state, exactly as a cold start would.
      await harness.pump(tester, const HoldingsScreen());

      expect(find.text('RELIANCE'), findsOneWidget);
      expect(find.text('4 @ ₹2,950.40'), findsOneWidget);
      expect(
        harness.container.read(portfolioControllerProvider).quantityHeld(
              'RELIANCE',
            ),
        4,
      );
    });

    testWidgets('selling the whole position removes the holding',
        (tester) async {
      final harness = AppHarness();
      await harness.pump(tester, const OrderTicketScreen(symbol: 'TCS'));

      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      await harness.pump(
        tester,
        const OrderTicketScreen(symbol: 'TCS', initialSide: OrderSide.sell),
      );
      await tester.enterText(find.byType(TextField), '3');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      expect(
        harness.container.read(portfolioControllerProvider).holdings,
        isEmpty,
      );

      await harness.pump(tester, const HoldingsScreen());
      expect(find.text('No holdings yet'), findsOneWidget);
    });
  });
}
