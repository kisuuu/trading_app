import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/market_feed.dart';
import '../data/mock_market_feed.dart';
import 'market_data_service.dart';

/// The mock feed. Swapping this override for a websocket-backed implementation
/// is the only change a real backend would require.
final Provider<MarketFeed> marketFeedProvider = Provider<MarketFeed>((ref) {
  return MockMarketFeed();
});

/// App-wide price distribution. Kept alive for the whole session: the feed must
/// keep running while the user is on the holdings tab so returning to the
/// market screen shows current prices, not the ones from when they left.
final Provider<MarketDataService> marketDataServiceProvider =
    Provider<MarketDataService>((ref) {
  final service = MarketDataService(feed: ref.watch(marketFeedProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Current tick rate, surfaced as a debug setting in the market screen.
final NotifierProvider<TickRateController, TickRate> tickRateProvider =
    NotifierProvider<TickRateController, TickRate>(TickRateController.new);

class TickRateController extends Notifier<TickRate> {
  @override
  TickRate build() => ref.watch(marketDataServiceProvider).rate;

  void set(TickRate rate) {
    ref.read(marketDataServiceProvider).setRate(rate);
    state = rate;
  }
}
