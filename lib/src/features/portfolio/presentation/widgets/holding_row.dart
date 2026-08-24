import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../market/presentation/widgets/price_flash.dart';
import '../../../market/presentation/widgets/quote_builder.dart';
import '../../domain/holding.dart';

/// One position, laid out as three numeric columns.
///
/// Only the live half of the row sits inside the [QuoteBuilder]: quantity and
/// average cost cannot change without a trade, so they are built once and are
/// not touched by ticks.
class HoldingRow extends StatelessWidget {
  const HoldingRow({required this.holding, required this.onTap, super.key});

  final Holding holding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: AppTheme.tabularFigures,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    holding.symbol,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${holding.quantity} @ '
                    '${MoneyFormatter.rupees(holding.averageCost)}',
                    style: secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 9,
              child: QuoteBuilder(
                symbol: holding.symbol,
                builder: (context, quote, _) {
                  final pnl = holding.unrealisedPnl(quote.ltp);
                  final pnlColor = MarketColors.forChange(pnl.paise);
                  return PriceFlash(
                    sequence: quote.sequence,
                    direction: quote.direction,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _Figure(
                            primary: MoneyFormatter.rupees(
                              holding.currentValue(quote.ltp),
                            ),
                            secondary:
                                'LTP ${MoneyFormatter.rupees(quote.ltp)}',
                            secondaryStyle: secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Figure(
                            primary: MoneyFormatter.signedRupees(pnl),
                            secondary: MoneyFormatter.signedPercent(
                              holding.pnlPercent(quote.ltp),
                            ),
                            color: pnlColor,
                            secondaryStyle:
                                secondary?.copyWith(color: pnlColor),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.primary,
    required this.secondary,
    this.color,
    this.secondaryStyle,
  });

  final String primary;
  final String secondary;
  final Color? color;
  final TextStyle? secondaryStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            primary,
            style: theme.textTheme.price.copyWith(fontSize: 14, color: color),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(secondary, style: secondaryStyle),
        ),
      ],
    );
  }
}
