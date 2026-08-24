import 'package:meta/meta.dart';

import '../../../core/money/money.dart';

enum OrderSide {
  buy('BUY'),
  sell('SELL');

  const OrderSide(this.label);

  final String label;

  bool get isBuy => this == OrderSide.buy;

  static OrderSide? parse(String name) {
    for (final side in OrderSide.values) {
      if (side.name == name) return side;
    }
    return null;
  }
}

/// An executed order. Orders are append-only history — nothing mutates one
/// after it fills, so the ledger always explains how the portfolio got here.
@immutable
class TradeOrder {
  const TradeOrder({
    required this.id,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.price,
    required this.placedAt,
  });

  final String id;
  final String symbol;
  final OrderSide side;
  final int quantity;

  /// The LTP captured at the instant of submission — not the live price. An
  /// order that filled at ₹2,950.40 keeps showing ₹2,950.40 forever.
  final Money price;

  final DateTime placedAt;

  /// Exact consideration: quantity x fill price, in integer paise.
  Money get value => price * quantity;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'symbol': symbol,
        'side': side.name,
        'quantity': quantity,
        'pricePaise': price.paise,
        'placedAt': placedAt.toIso8601String(),
      };

  static TradeOrder? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final symbol = json['symbol'];
    final side = json['side'];
    final quantity = json['quantity'];
    final price = json['pricePaise'];
    final placedAt = json['placedAt'];
    if (id is! String ||
        symbol is! String ||
        side is! String ||
        quantity is! int ||
        price is! int ||
        placedAt is! String) {
      return null;
    }
    final parsedSide = OrderSide.parse(side);
    final parsedTime = DateTime.tryParse(placedAt);
    if (parsedSide == null || parsedTime == null) return null;
    return TradeOrder(
      id: id,
      symbol: symbol,
      side: parsedSide,
      quantity: quantity,
      price: Money(price),
      placedAt: parsedTime,
    );
  }
}
