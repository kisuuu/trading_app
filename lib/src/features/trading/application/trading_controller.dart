import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids.dart';
import '../../../core/persistence/store_provider.dart';
import '../../market/application/market_providers.dart';
import '../../portfolio/application/portfolio_controller.dart';
import '../data/order_history_repository.dart';
import '../domain/order_executor.dart';
import '../domain/order_failure.dart';
import '../domain/trade_order.dart';

final Provider<OrderHistoryRepository> orderHistoryRepositoryProvider =
    Provider<OrderHistoryRepository>(
  (ref) => OrderHistoryRepository(ref.watch(keyValueStoreProvider)),
);

/// Executed orders, newest first.
class OrderHistoryController extends Notifier<List<TradeOrder>> {
  late final OrderHistoryRepository _repository;

  @override
  List<TradeOrder> build() {
    _repository = ref.watch(orderHistoryRepositoryProvider);
    return _repository.load();
  }

  void record(TradeOrder order) {
    final next = <TradeOrder>[order, ...state];
    state = next;
    _repository.save(next).catchError(
          (Object error) => debugPrint('Failed to save order history: $error'),
        );
  }

  void clear() {
    state = const <TradeOrder>[];
    _repository.save(const <TradeOrder>[]).catchError(
          (Object error) => debugPrint('Failed to clear order history: $error'),
        );
  }
}

final NotifierProvider<OrderHistoryController, List<TradeOrder>>
    orderHistoryProvider =
    NotifierProvider<OrderHistoryController, List<TradeOrder>>(
  OrderHistoryController.new,
);

/// Places orders: samples the live price, runs the pure executor, then commits
/// the portfolio and the ledger together.
class TradingController {
  const TradingController(this._ref);

  final Ref _ref;

  /// Submits [draft] at the LTP **read at this instant**.
  ///
  /// The price is deliberately sampled here rather than taken from the form.
  /// The ticket's displayed price is one frame old at best, and under a fast
  /// feed it can be several ticks stale; sampling at submission is what makes
  /// "executes at the current LTP at the moment of submission" literally true.
  OrderResult submit(OrderDraft draft) {
    final market = _ref.read(marketDataServiceProvider);
    final quote = market.quoteOrNull(draft.symbol);
    if (quote == null) {
      return OrderRejected(PriceUnavailable(draft.symbol));
    }

    final result = OrderExecutor.execute(
      portfolio: _ref.read(portfolioControllerProvider),
      draft: draft,
      price: quote.ltp,
      orderId: Ids.next('ord'),
      placedAt: DateTime.now(),
    );

    if (result case OrderFilled(:final portfolio, :final order)) {
      _ref.read(portfolioControllerProvider.notifier).replaceWith(portfolio);
      _ref.read(orderHistoryProvider.notifier).record(order);
    }
    return result;
  }
}

final Provider<TradingController> tradingControllerProvider =
    Provider<TradingController>(TradingController.new);
