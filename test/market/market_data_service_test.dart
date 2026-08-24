import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/core/money/money.dart';
import 'package:trading_app/src/core/scheduler/frame_scheduler.dart';
import 'package:trading_app/src/features/market/application/market_data_service.dart';
import 'package:trading_app/src/features/market/data/market_feed.dart';
import 'package:trading_app/src/features/market/data/mock_market_feed.dart';
import 'package:trading_app/src/features/market/domain/quote.dart';
import 'package:trading_app/src/features/market/domain/stock.dart';

import '../support/fake_market_feed.dart';

void main() {
  late FakeMarketFeed feed;
  late ManualFrameScheduler scheduler;
  late MarketDataService service;

  setUp(() {
    feed = FakeMarketFeed();
    scheduler = ManualFrameScheduler();
    service = MarketDataService(feed: feed, scheduler: scheduler);
  });

  tearDown(() => service.dispose());

  group('coalescing', () {
    test('collapses many ticks in one frame into a single notification', () {
      var notifications = 0;
      service.quoteListenable('RELIANCE').addListener(() => notifications++);

      for (var i = 1; i <= 50; i++) {
        feed.tickRupees('RELIANCE', 2950 + i);
      }

      // Nothing has reached the UI yet — the frame has not run.
      expect(notifications, 0);
      expect(service.quote('RELIANCE').ltp, const Money(295040));

      scheduler.flush();

      expect(notifications, 1);
      expect(service.quote('RELIANCE').ltp, Money.fromRupees(3000));
      expect(service.ticksReceived, 50);
      expect(service.flushCount, 1);
    });

    test('only symbols that ticked are notified', () {
      var reliance = 0;
      var tcs = 0;
      service.quoteListenable('RELIANCE').addListener(() => reliance++);
      service.quoteListenable('TCS').addListener(() => tcs++);

      feed.tickRupees('RELIANCE', 2960);
      scheduler.flush();

      expect(reliance, 1);
      expect(tcs, 0);
    });

    test('bumps the epoch once per flush, after every notifier is written', () {
      final pricesAtEpoch = <String, Money>{};
      service.epoch.addListener(() {
        for (final symbol in StockUniverse.symbols) {
          pricesAtEpoch[symbol] = service.quote(symbol).ltp;
        }
      });

      feed.tickRupees('RELIANCE', 3000);
      feed.tickRupees('TCS', 4200);
      scheduler.flush();

      // The aggregate listener sees both new prices, never a half-applied
      // frame — this is what keeps the portfolio total equal to its rows.
      expect(pricesAtEpoch['RELIANCE'], Money.fromRupees(3000));
      expect(pricesAtEpoch['TCS'], Money.fromRupees(4200));
      expect(service.epoch.value, 1);
    });

    test('schedules at most one flush regardless of pending tick count', () {
      feed.tickRupees('RELIANCE', 2960);
      feed.tickRupees('TCS', 4200);
      feed.tickRupees('INFY', 1870);
      expect(scheduler.hasPendingFlush, isTrue);

      scheduler.flush();
      expect(service.flushCount, 1);
      expect(scheduler.hasPendingFlush, isFalse);
    });
  });

  group('single source of truth', () {
    test('every reader of a symbol shares one notifier instance', () {
      expect(
        identical(
          service.quoteListenable('RELIANCE'),
          service.quoteListenable('RELIANCE'),
        ),
        isTrue,
      );
    });

    test('the same symbol in two watchlists cannot diverge', () {
      // Two independent subscribers, as two watchlist rows would be.
      Quote? fromListA;
      Quote? fromListB;
      service.quoteListenable('INFY').addListener(
            () => fromListA = service.quote('INFY'),
          );
      service.quoteListenable('INFY').addListener(
            () => fromListB = service.quote('INFY'),
          );

      feed.tickRupees('INFY', 1899.55);
      scheduler.flush();

      expect(fromListA, isNotNull);
      expect(identical(fromListA, fromListB), isTrue);
    });

    test('unknown symbols fail loudly, or softly where data is restored', () {
      expect(() => service.quoteListenable('NOTREAL'), throwsArgumentError);
      expect(service.quoteOrNull('NOTREAL'), isNull);
    });
  });

  group('tick direction', () {
    test('reports up and down separately', () {
      feed.tickRupees('SBIN', 820);
      scheduler.flush();
      expect(service.quote('SBIN').direction, TickDirection.up);

      feed.tickRupees('SBIN', 810);
      scheduler.flush();
      expect(service.quote('SBIN').direction, TickDirection.down);
    });

    test('sequence advances even when the price is unchanged', () {
      feed.tickRupees('ITC', 447.25);
      scheduler.flush();
      final quote = service.quote('ITC');
      expect(quote.ltp, const Money(44725));
      expect(quote.sequence, 1);
      expect(quote.direction, TickDirection.unchanged);
    });
  });

  group('lifecycle', () {
    test('pauses the feed in the background and rolls it forward on resume', () {
      service.onAppPaused();
      expect(feed.pauseCalls, 1);

      service.onAppResumed();
      expect(feed.lastResumeOffset, isNotNull);
    });
  });

  group('MockMarketFeed', () {
    test('keeps prices inside the circuit band over a long run', () {
      final mock = MockMarketFeed(random: Random(7));
      addTearDown(mock.dispose);

      // 5000 ticks per symbol, far more than a session would produce.
      mock.resumeAfter(const Duration(hours: 10));
      mock.pause();

      for (final stock in StockUniverse.stocks) {
        final ltp = mock.snapshot[stock.symbol]!.ltp.paise;
        expect(ltp, greaterThanOrEqualTo((stock.previousClose.paise * 0.8).round()));
        expect(ltp, lessThanOrEqualTo((stock.previousClose.paise * 1.2).round()));
      }
    });

    test('is deterministic for a given seed', () {
      final first = MockMarketFeed(random: Random(42))
        ..resumeAfter(const Duration(seconds: 5))
        ..pause();
      final second = MockMarketFeed(random: Random(42))
        ..resumeAfter(const Duration(seconds: 5))
        ..pause();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      for (final symbol in StockUniverse.symbols) {
        expect(first.snapshot[symbol]!.ltp, second.snapshot[symbol]!.ltp);
      }
    });

    test('every tick moves the price so the tape never looks frozen', () {
      final mock = MockMarketFeed(random: Random(3));
      addTearDown(mock.dispose);

      mock.resumeAfter(const Duration(seconds: 2));
      mock.pause();

      expect(mock.snapshot['ITC']!.ltp, isNot(const Money(44725)));
    });

    test('exposes a configurable rate', () {
      final mock = MockMarketFeed();
      addTearDown(mock.dispose);

      expect(mock.rate, TickRate.normal);
      mock.setRate(TickRate.stress);
      expect(mock.rate, TickRate.stress);
      expect(TickRate.stress.totalTicksPerSecond(10), 250);
    });
  });
}
