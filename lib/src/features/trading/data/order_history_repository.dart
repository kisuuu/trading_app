import '../../../core/persistence/key_value_store.dart';
import '../domain/trade_order.dart';

/// Persists the executed-order ledger, newest first.
class OrderHistoryRepository {
  const OrderHistoryRepository(this._store);

  static const String _key = 'orders.v1';

  /// Keeps local storage bounded on a long-lived install. The ledger is a
  /// convenience view, not an audit record.
  static const int maxOrders = 200;

  final KeyValueStore _store;

  List<TradeOrder> load() {
    final rows = _store.readJsonArray(_key);
    if (rows == null) return const <TradeOrder>[];
    return <TradeOrder>[
      for (final row in rows)
        if (TradeOrder.fromJson(row) case final TradeOrder order) order,
    ];
  }

  Future<void> save(List<TradeOrder> orders) {
    final bounded =
        orders.length > maxOrders ? orders.sublist(0, maxOrders) : orders;
    return _store.writeJson(
      _key,
      <Object?>[for (final order in bounded) order.toJson()],
    );
  }
}
