import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/money/money_formatter.dart';
import '../../market/domain/stock.dart';
import '../domain/trade_order.dart';

/// Terminal confirmation for a filled order.
///
/// Shows the price the order actually executed at — a frozen number, not the
/// live LTP, so the record cannot drift away from what the user agreed to.
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({required this.order, super.key});

  final TradeOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = order.side.isBuy ? MarketColors.up : MarketColors.down;

    return Scaffold(
      appBar: AppBar(title: const Text('Order placed')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline, size: 40, color: accent),
                    const SizedBox(height: 10),
                    Text(
                      '${order.side.label} ${order.quantity} '
                      '${order.symbol}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Executed at ${MoneyFormatter.rupees(order.price)} '
                      'per share',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _DetailRow(label: 'Stock', value: StockUniverse.nameOf(order.symbol)),
              _DetailRow(label: 'Side', value: order.side.label),
              _DetailRow(label: 'Quantity', value: '${order.quantity}'),
              _DetailRow(
                label: 'Fill price',
                value: MoneyFormatter.rupees(order.price),
              ),
              _DetailRow(
                label: 'Order value',
                value: MoneyFormatter.rupees(order.value),
                emphasise: true,
              ),
              _DetailRow(label: 'Placed at', value: _formatTime(order.placedAt)),
              _DetailRow(label: 'Order ID', value: order.id),
              const Spacer(),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.price.copyWith(
                fontSize: emphasise ? 17 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
