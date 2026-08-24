import 'package:flutter/material.dart';

import '../features/trading/domain/trade_order.dart';
import '../features/trading/presentation/order_ticket_screen.dart';

/// Route helpers, so screens do not need to know each other's constructors.
abstract final class AppNavigator {
  /// Opens the Buy/Sell ticket pre-filled for [symbol].
  static Future<void> openTicket(
    BuildContext context, {
    required String symbol,
    OrderSide side = OrderSide.buy,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OrderTicketScreen(symbol: symbol, initialSide: side),
      ),
    );
  }
}
