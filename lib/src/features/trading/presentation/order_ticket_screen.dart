import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../market/domain/stock.dart';
import '../../market/presentation/widgets/price_flash.dart';
import '../../market/presentation/widgets/quote_builder.dart';
import '../../portfolio/application/portfolio_controller.dart';
import '../application/trading_controller.dart';
import '../domain/order_executor.dart';
import '../domain/order_failure.dart';
import '../domain/trade_order.dart';
import 'order_confirmation_screen.dart';

/// Market order ticket for a single stock.
///
/// Two things are live at once: the price (ticking from the feed) and the
/// quantity (typed by the user). Everything derived from both — order value,
/// the inline error, whether submit is enabled — is rebuilt inside a single
/// [QuoteBuilder] so a tick refreshes the numbers without disturbing the text
/// field or its cursor.
class OrderTicketScreen extends ConsumerStatefulWidget {
  const OrderTicketScreen({
    required this.symbol,
    this.initialSide = OrderSide.buy,
    super.key,
  });

  final String symbol;
  final OrderSide initialSide;

  @override
  ConsumerState<OrderTicketScreen> createState() => _OrderTicketScreenState();
}

class _OrderTicketScreenState extends ConsumerState<OrderTicketScreen> {
  final TextEditingController _quantityController = TextEditingController();

  late OrderSide _side = widget.initialSide;

  /// Errors stay hidden until the user has engaged with the field or tried to
  /// submit, so opening the ticket does not greet them with "Enter a quantity".
  bool _showErrors = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _setSide(OrderSide side) {
    if (_side == side) return;
    setState(() => _side = side);
  }

  void _setQuantity(int quantity) {
    _quantityController.text = '$quantity';
    _quantityController.selection = TextSelection.collapsed(
      offset: _quantityController.text.length,
    );
    setState(() => _showErrors = true);
  }

  void _submit(int quantity) {
    setState(() => _showErrors = true);

    final result = ref.read(tradingControllerProvider).submit(
          OrderDraft(
            symbol: widget.symbol,
            side: _side,
            quantity: quantity,
          ),
        );

    switch (result) {
      case OrderFilled(:final order):
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => OrderConfirmationScreen(order: order),
          ),
        );
      case OrderRejected(:final failure):
        // The price can move between the last rebuild and the tap, so an order
        // that looked valid a frame ago may be rejected here. Surface it rather
        // than failing silently.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: MarketColors.down,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = StockUniverse.find(widget.symbol);
    if (stock == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.symbol)),
        body: Center(child: Text(UnknownSymbol(widget.symbol).message)),
      );
    }

    final portfolio = ref.watch(portfolioControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(stock.symbol),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                stock.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            _LivePriceHeader(symbol: widget.symbol),
            const SizedBox(height: 20),
            _SideSelector(side: _side, onChanged: _setSide),
            const SizedBox(height: 20),
            _QuantityField(
              controller: _quantityController,
              onChanged: (_) => setState(() => _showErrors = true),
            ),
            const SizedBox(height: 12),
            // Everything below depends on price *and* quantity. Rebuilt on both
            // ticks and keystrokes; the field above is not.
            QuoteBuilder(
              symbol: widget.symbol,
              builder: (context, quote, _) {
                final (quantity, quantityFailure) =
                    OrderExecutor.parseQuantity(_quantityController.text);

                final failure = quantityFailure ??
                    (quantity == null
                        ? null
                        : OrderExecutor.validate(
                            portfolio: portfolio,
                            draft: OrderDraft(
                              symbol: widget.symbol,
                              side: _side,
                              quantity: quantity,
                            ),
                            price: quote.ltp,
                          ));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _QuickQuantities(
                      side: _side,
                      ltp: quote.ltp,
                      cash: portfolio.cash,
                      held: portfolio.quantityHeld(widget.symbol),
                      onSelected: _setQuantity,
                    ),
                    const SizedBox(height: 16),
                    _OrderSummary(
                      side: _side,
                      quantity: quantity,
                      ltp: quote.ltp,
                      cash: portfolio.cash,
                      held: portfolio.quantityHeld(widget.symbol),
                    ),
                    if (_showErrors && failure != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _InlineError(message: failure.message),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _side.isBuy ? MarketColors.up : MarketColors.down,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      onPressed: failure != null || quantity == null
                          ? null
                          : () => _submit(quantity),
                      child: Text(
                        '${_side.label} '
                        '${quantity == null ? '' : '$quantity '}'
                        '${stock.symbol}',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Market order · executes at the last traded price when '
                      'you submit',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Large ticking price at the top of the ticket.
class _LivePriceHeader extends StatelessWidget {
  const _LivePriceHeader({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return QuoteBuilder(
      symbol: symbol,
      builder: (context, quote, _) {
        final changeColor = MarketColors.forChange(quote.change.paise);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: PriceFlash(
                  sequence: quote.sequence,
                  direction: quote.direction,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    MoneyFormatter.rupees(quote.ltp),
                    style: theme.textTheme.priceLarge,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: <Widget>[
                      Icon(
                        quote.isUp
                            ? Icons.arrow_drop_up
                            : quote.isDown
                                ? Icons.arrow_drop_down
                                : Icons.remove,
                        size: 18,
                        color: changeColor,
                      ),
                      Text(
                        '${MoneyFormatter.signedRupees(quote.change)} '
                        '(${MoneyFormatter.signedPercent(quote.changePercent)})',
                        style:
                            theme.textTheme.change.copyWith(color: changeColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SideSelector extends StatelessWidget {
  const _SideSelector({required this.side, required this.onChanged});

  final OrderSide side;
  final ValueChanged<OrderSide> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<OrderSide>(
      segments: const <ButtonSegment<OrderSide>>[
        ButtonSegment<OrderSide>(value: OrderSide.buy, label: Text('BUY')),
        ButtonSegment<OrderSide>(value: OrderSide.sell, label: Text('SELL')),
      ],
      selected: <OrderSide>{side},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor:
            side.isBuy ? MarketColors.up : MarketColors.down,
        selectedForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
      ),
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      // Intentionally *not* digit-filtered: rejecting "2.5" or "-3" with an
      // explanation is clearer than silently swallowing the keystroke.
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: Theme.of(context).textTheme.price.copyWith(fontSize: 18),
      decoration: const InputDecoration(
        labelText: 'Quantity',
        hintText: 'Number of shares',
        prefixIcon: Icon(Icons.numbers, size: 20),
      ),
    );
  }
}

/// Shortcut chips, including a MAX that is exact: for a buy it is the largest
/// quantity the balance covers at the current price.
class _QuickQuantities extends StatelessWidget {
  const _QuickQuantities({
    required this.side,
    required this.ltp,
    required this.cash,
    required this.held,
    required this.onSelected,
  });

  final OrderSide side;
  final Money ltp;
  final Money cash;
  final int held;
  final ValueChanged<int> onSelected;

  int get _max {
    if (!side.isBuy) return held;
    if (ltp.paise <= 0) return 0;
    return cash.paise ~/ ltp.paise;
  }

  @override
  Widget build(BuildContext context) {
    final max = _max;
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final quantity in const <int>[1, 10, 50, 100])
          ActionChip(
            label: Text('$quantity'),
            onPressed: () => onSelected(quantity),
          ),
        if (max > 0)
          ActionChip(
            label: Text('MAX $max'),
            onPressed: () => onSelected(max),
          ),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.side,
    required this.quantity,
    required this.ltp,
    required this.cash,
    required this.held,
  });

  final OrderSide side;
  final int? quantity;
  final Money ltp;
  final Money cash;
  final int held;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = quantity == null ? Money.zero : ltp * quantity!;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          children: <Widget>[
            _SummaryRow(
              label: 'Order value',
              value: MoneyFormatter.rupees(value),
              emphasise: true,
            ),
            const SizedBox(height: 10),
            _SummaryRow(
              label: side.isBuy ? 'Available margin' : 'Shares held',
              value: side.isBuy
                  ? MoneyFormatter.rupees(cash)
                  : '$held',
            ),
            if (side.isBuy) ...<Widget>[
              const SizedBox(height: 10),
              _SummaryRow(
                label: 'Balance after order',
                value: MoneyFormatter.rupees(cash - value),
                valueColor: MarketColors.forChange((cash - value).paise),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasise = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasise;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: theme.textTheme.price.copyWith(
                fontSize: emphasise ? 18 : 15,
                color: valueColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MarketColors.down.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MarketColors.down.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18, color: MarketColors.down),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: MarketColors.down),
            ),
          ),
        ],
      ),
    );
  }
}
