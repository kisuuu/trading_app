import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/core/money/money.dart';
import 'package:trading_app/src/core/scheduler/frame_scheduler.dart';
import 'package:trading_app/src/features/market/application/market_data_service.dart';
import 'package:trading_app/src/features/portfolio/application/holdings_sort.dart';
import 'package:trading_app/src/features/portfolio/domain/holding.dart';

import '../support/fake_market_feed.dart';

const List<Holding> holdings = <Holding>[
  // 10 shares at 2,950.40 — RELIANCE's previous close.
  Holding(symbol: 'RELIANCE', quantity: 10, totalCost: Money(2950400)),
  // 5 shares at 4,125.80 — TCS's previous close.
  Holding(symbol: 'TCS', quantity: 5, totalCost: Money(2062900)),
];

void main() {
  late FakeMarketFeed feed;
  late ManualFrameScheduler scheduler;
  late MarketDataService market;

  setUp(() {
    feed = FakeMarketFeed();
    scheduler = ManualFrameScheduler();
    market = MarketDataService(feed: feed, scheduler: scheduler);
  });

  tearDown(() => market.dispose());

  HoldingsOrderNotifier orderBy(HoldingsSort sort) {
    final notifier = HoldingsOrderNotifier(
      market: market,
      holdings: holdings,
      sort: sort,
    );
    addTearDown(notifier.dispose);
    return notifier;
  }

  test('sorts by symbol without touching prices', () {
    expect(
      orderBy(HoldingsSort.symbolAscending).value,
      <String>['RELIANCE', 'TCS'],
    );
  });

  test('reorders when a position crosses from loss to gain', () {
    final order = orderBy(HoldingsSort.pnlDescending);

    // Both flat at cost, so the symbol tiebreaker decides.
    expect(order.value, <String>['RELIANCE', 'TCS']);

    // TCS rallies while RELIANCE slips: TCS must move to the top.
    feed.tickRupees('TCS', 4300);
    feed.tickRupees('RELIANCE', 2900);
    scheduler.flush();

    expect(order.value, <String>['TCS', 'RELIANCE']);
  });

  test('publishes a new order only when the sequence actually changes', () {
    final order = orderBy(HoldingsSort.pnlDescending);
    var notifications = 0;
    order.addListener(() => notifications++);

    // Prices move repeatedly, but never enough to swap the ranking.
    for (var i = 1; i <= 10; i++) {
      feed.tickRupees('RELIANCE', 2950.40 + i * 0.05);
      scheduler.flush();
    }
    expect(notifications, 0, reason: 'ranking unchanged, so no list rebuild');

    // Now TCS overtakes and the list does need to move.
    feed.tickRupees('TCS', 4500);
    scheduler.flush();
    expect(notifications, 1);
    expect(order.value, <String>['TCS', 'RELIANCE']);
  });

  test('sorts ascending and by current value', () {
    feed.tickRupees('TCS', 4300);
    feed.tickRupees('RELIANCE', 2900);
    scheduler.flush();

    expect(
      orderBy(HoldingsSort.pnlAscending).value,
      <String>['RELIANCE', 'TCS'],
    );
    // 10 x 2,900 = 29,000 against 5 x 4,300 = 21,500.
    expect(
      orderBy(HoldingsSort.currentValueDescending).value,
      <String>['RELIANCE', 'TCS'],
    );
  });

  test('a symbol-sorted list does not subscribe to price flushes', () {
    final order = orderBy(HoldingsSort.symbolAscending);
    var notifications = 0;
    order.addListener(() => notifications++);

    feed.tickRupees('TCS', 9999);
    scheduler.flush();

    expect(notifications, 0);
  });
}
