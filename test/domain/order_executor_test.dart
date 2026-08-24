import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/core/money/money.dart';
import 'package:trading_app/src/features/portfolio/domain/portfolio.dart';
import 'package:trading_app/src/features/trading/domain/order_executor.dart';
import 'package:trading_app/src/features/trading/domain/order_failure.dart';
import 'package:trading_app/src/features/trading/domain/trade_order.dart';

const String symbol = 'RELIANCE';
final DateTime at = DateTime(2026, 8, 24, 10, 30);

OrderResult buy(Portfolio portfolio, int quantity, Money price) {
  return OrderExecutor.execute(
    portfolio: portfolio,
    draft: OrderDraft(symbol: symbol, side: OrderSide.buy, quantity: quantity),
    price: price,
    orderId: 'test',
    placedAt: at,
  );
}

OrderResult sell(Portfolio portfolio, int quantity, Money price) {
  return OrderExecutor.execute(
    portfolio: portfolio,
    draft: OrderDraft(symbol: symbol, side: OrderSide.sell, quantity: quantity),
    price: price,
    orderId: 'test',
    placedAt: at,
  );
}

Portfolio filled(OrderResult result) => (result as OrderFilled).portfolio;

void main() {
  group('quantity parsing', () {
    test('accepts whole positive quantities', () {
      expect(OrderExecutor.parseQuantity('10'), (10, null));
      expect(OrderExecutor.parseQuantity(' 7 '), (7, null));
    });

    test('rejects fractional quantities with a specific reason', () {
      final (quantity, failure) = OrderExecutor.parseQuantity('2.5');
      expect(quantity, isNull);
      expect(
        failure,
        isA<InvalidQuantity>().having(
          (f) => f.reason,
          'reason',
          QuantityRejection.fractional,
        ),
      );
    });

    test('rejects zero and negative quantities', () {
      for (final input in <String>['0', '-3', '-0.5']) {
        final (quantity, failure) = OrderExecutor.parseQuantity(input);
        expect(quantity, isNull, reason: input);
        expect(
          failure,
          isA<InvalidQuantity>().having(
            (f) => f.reason,
            'reason',
            QuantityRejection.notPositive,
          ),
          reason: input,
        );
      }
    });

    test('rejects empty and non-numeric input distinctly', () {
      expect(
        OrderExecutor.parseQuantity('').$2,
        isA<InvalidQuantity>()
            .having((f) => f.reason, 'reason', QuantityRejection.empty),
      );
      expect(
        OrderExecutor.parseQuantity('abc').$2,
        isA<InvalidQuantity>()
            .having((f) => f.reason, 'reason', QuantityRejection.notANumber),
      );
    });

    test('rejects quantities beyond the per-order cap', () {
      expect(
        OrderExecutor.parseQuantity('99999999999999999999').$2,
        isA<InvalidQuantity>(),
      );
    });
  });

  group('buy', () {
    test('debits cash exactly and opens a holding', () {
      final result = buy(Portfolio.initial, 10, const Money(295040));
      final portfolio = filled(result);

      // 10,00,000.00 - (10 x 2,950.40) = 9,70,496.00
      expect(portfolio.cash, const Money(97049600));
      expect(portfolio.quantityHeld(symbol), 10);
      expect(portfolio.holdingOf(symbol)!.totalCost, const Money(2950400));
      expect(portfolio.holdingOf(symbol)!.averageCost, const Money(295040));
    });

    test('averages cost across multiple buys without drift', () {
      var portfolio = filled(buy(Portfolio.initial, 3, const Money(333333)));
      portfolio = filled(buy(portfolio, 2, const Money(100000)));

      final holding = portfolio.holdingOf(symbol)!;
      expect(holding.quantity, 5);
      // 3 x 3,333.33 + 2 x 1,000.00 = 11,999.99
      expect(holding.totalCost, const Money(1199999));
      expect(holding.averageCost, const Money(240000)); // 2,400.00 (rounded)
    });

    test('cost basis stays exact over 100 buys', () {
      var portfolio = Portfolio.initial;
      for (var i = 0; i < 100; i++) {
        portfolio = filled(buy(portfolio, 1, const Money(101010)));
      }
      expect(portfolio.holdingOf(symbol)!.totalCost, const Money(10101000));
      expect(
        portfolio.cash,
        Portfolio.openingCash - const Money(10101000),
      );
    });

    test('is blocked when order value exceeds the balance', () {
      final result = buy(Portfolio.initial, 1000, const Money(295040));

      expect(result, isA<OrderRejected>());
      final failure = (result as OrderRejected).failure;
      expect(failure, isA<InsufficientFunds>());
      expect((failure as InsufficientFunds).required, const Money(295040000));
      expect(failure.available, Portfolio.openingCash);
      expect(failure.message, contains('exceeds your available balance'));
    });

    test('allows spending the balance down to exactly zero', () {
      const portfolio = Portfolio(cash: Money(590080), holdings: {});
      final result = buy(portfolio, 2, const Money(295040));

      expect(result, isA<OrderFilled>());
      expect(filled(result).cash, Money.zero);
    });

    test('rejects a symbol outside the universe', () {
      final result = OrderExecutor.execute(
        portfolio: Portfolio.initial,
        draft: const OrderDraft(
          symbol: 'NOTREAL',
          side: OrderSide.buy,
          quantity: 1,
        ),
        price: const Money(100),
        orderId: 'test',
        placedAt: at,
      );
      expect((result as OrderRejected).failure, isA<UnknownSymbol>());
    });
  });

  group('sell', () {
    test('credits cash and reduces quantity, keeping average cost stable', () {
      final opened = filled(buy(Portfolio.initial, 10, const Money(200000)));
      final portfolio = filled(sell(opened, 4, const Money(250000)));

      final holding = portfolio.holdingOf(symbol)!;
      expect(holding.quantity, 6);
      expect(holding.averageCost, const Money(200000));
      expect(holding.totalCost, const Money(1200000));
      // 8,00,000 spent, 10,000 x 4 back = cash rises by the sale proceeds.
      expect(portfolio.cash, opened.cash + const Money(1000000));
    });

    test('removes the holding entirely when quantity reaches zero', () {
      final opened = filled(buy(Portfolio.initial, 5, const Money(200000)));
      final portfolio = filled(sell(opened, 5, const Money(210000)));

      expect(portfolio.holdingOf(symbol), isNull);
      expect(portfolio.holdings, isEmpty);
      expect(portfolio.cash, const Money(100050000)); // 10,00,000 + 500 profit
    });

    test('is blocked beyond the held quantity', () {
      final opened = filled(buy(Portfolio.initial, 5, const Money(200000)));
      final result = sell(opened, 6, const Money(200000));

      final failure = (result as OrderRejected).failure;
      expect(failure, isA<InsufficientQuantityHeld>());
      expect((failure as InsufficientQuantityHeld).held, 5);
      expect(failure.message, contains('You hold only 5 shares'));
    });

    test('is blocked when nothing is held', () {
      final result = sell(Portfolio.initial, 1, const Money(200000));
      final failure = (result as OrderRejected).failure;
      expect(failure, isA<InsufficientQuantityHeld>());
      expect(failure.message, contains('do not hold any shares'));
    });
  });

  group('validate', () {
    test('mirrors execute without mutating anything', () {
      final failure = OrderExecutor.validate(
        portfolio: Portfolio.initial,
        draft: const OrderDraft(
          symbol: symbol,
          side: OrderSide.buy,
          quantity: 1000,
        ),
        price: const Money(295040),
      );
      expect(failure, isA<InsufficientFunds>());
    });

    test('rejects a non-positive price', () {
      final failure = OrderExecutor.validate(
        portfolio: Portfolio.initial,
        draft: const OrderDraft(
          symbol: symbol,
          side: OrderSide.buy,
          quantity: 1,
        ),
        price: Money.zero,
      );
      expect(failure, isA<PriceUnavailable>());
    });
  });
}
