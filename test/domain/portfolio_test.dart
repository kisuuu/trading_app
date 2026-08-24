import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/core/money/money.dart';
import 'package:trading_app/src/core/persistence/key_value_store.dart';
import 'package:trading_app/src/core/scheduler/frame_scheduler.dart';
import 'package:trading_app/src/features/market/application/market_data_service.dart';
import 'package:trading_app/src/features/portfolio/application/portfolio_summary.dart';
import 'package:trading_app/src/features/portfolio/data/portfolio_repository.dart';
import 'package:trading_app/src/features/portfolio/domain/holding.dart';
import 'package:trading_app/src/features/portfolio/domain/portfolio.dart';

import '../support/fake_market_feed.dart';

void main() {
  group('Holding', () {
    const holding = Holding(
      symbol: 'RELIANCE',
      quantity: 10,
      totalCost: Money(2950400),
    );

    test('derives average cost from the exact total', () {
      expect(holding.averageCost, const Money(295040));
    });

    test('computes value and P&L against a live price', () {
      expect(holding.currentValue(const Money(300000)), const Money(3000000));
      expect(holding.unrealisedPnl(const Money(300000)), const Money(49600));
      expect(
        holding.pnlPercent(const Money(300000)),
        closeTo(1.6811, 0.0001),
      );
    });

    test('reports a loss as a negative figure', () {
      expect(holding.unrealisedPnl(const Money(290000)), const Money(-50400));
      expect(holding.pnlPercent(const Money(290000)), lessThan(0));
    });
  });

  group('persistence', () {
    late InMemoryKeyValueStore store;
    late PortfolioRepository repository;

    setUp(() {
      store = InMemoryKeyValueStore();
      repository = PortfolioRepository(store);
    });

    test('starts with the opening balance and no positions', () {
      final portfolio = repository.load();
      expect(portfolio.cash, Portfolio.openingCash);
      expect(portfolio.holdings, isEmpty);
    });

    test('round-trips cash and holdings together', () async {
      const portfolio = Portfolio(
        cash: Money(97049600),
        holdings: <String, Holding>{
          'RELIANCE': Holding(
            symbol: 'RELIANCE',
            quantity: 10,
            totalCost: Money(2950400),
          ),
        },
      );
      await repository.save(portfolio);

      final restored = repository.load();
      expect(restored.cash, const Money(97049600));
      expect(restored.holdingOf('RELIANCE')!.quantity, 10);
      expect(restored.holdingOf('RELIANCE')!.totalCost, const Money(2950400));
    });

    test('falls back to the opening portfolio on a corrupt payload', () async {
      await store.writeString('portfolio.v1', 'garbage');
      expect(repository.load().cash, Portfolio.openingCash);
    });

    test('drops malformed holdings but keeps cash', () async {
      await store.writeString(
        'portfolio.v1',
        '{"cashPaise":500,"holdings":[{"symbol":"TCS"},'
            '{"symbol":"INFY","quantity":2,"totalCostPaise":100}]}',
      );
      final restored = repository.load();
      expect(restored.cash, const Money(500));
      expect(restored.holdings.keys, <String>['INFY']);
    });
  });

  group('PortfolioSummary', () {
    test('equals the sum of the individual rows', () {
      final feed = FakeMarketFeed();
      final scheduler = ManualFrameScheduler();
      final market = MarketDataService(feed: feed, scheduler: scheduler);
      addTearDown(market.dispose);

      const holdings = <Holding>[
        Holding(symbol: 'RELIANCE', quantity: 10, totalCost: Money(2950400)),
        Holding(symbol: 'TCS', quantity: 5, totalCost: Money(2062900)),
      ];

      feed.tickRupees('RELIANCE', 3000);
      feed.tickRupees('TCS', 4200);
      scheduler.flush();

      final summary = PortfolioSummary.of(holdings, market);

      final rowValues = holdings
          .map((h) => h.currentValue(market.quote(h.symbol).ltp))
          .fold(Money.zero, (a, b) => a + b);
      final rowPnl = holdings
          .map((h) => h.unrealisedPnl(market.quote(h.symbol).ltp))
          .fold(Money.zero, (a, b) => a + b);

      expect(summary.invested, const Money(5013300));
      expect(summary.currentValue, rowValues);
      expect(summary.pnl, rowPnl);
      expect(summary.positions, 2);
    });

    test('an empty portfolio has zero everything and no NaN percent', () {
      final feed = FakeMarketFeed();
      final market = MarketDataService(
        feed: feed,
        scheduler: ManualFrameScheduler(),
      );
      addTearDown(market.dispose);

      final summary = PortfolioSummary.of(const <Holding>[], market);
      expect(summary.pnl, Money.zero);
      expect(summary.pnlPercent, 0);
      expect(summary.isEmpty, isTrue);
    });
  });
}
