import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../market/application/market_providers.dart';
import '../../application/portfolio_controller.dart';
import '../../application/portfolio_summary.dart';

/// Aggregate figures across every holding.
///
/// Bound to the service's flush epoch rather than to ten individual quotes: one
/// rebuild per frame regardless of how many symbols moved, and the totals are
/// computed from the same post-flush prices the rows are rendering, so the
/// summary always reconciles to the list.
class PortfolioSummaryCard extends ConsumerWidget {
  const PortfolioSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final holdings = ref.watch(holdingsProvider);
    final cash = ref.watch(availableCashProvider);
    final market = ref.watch(marketDataServiceProvider);

    return ValueListenableBuilder<int>(
      valueListenable: market.epoch,
      builder: (context, _, __) {
        final summary = PortfolioSummary.of(holdings, market);
        final pnlColor = MarketColors.forChange(summary.pnl.paise);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('TOTAL P&L', style: theme.textTheme.columnLabel),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      MoneyFormatter.signedRupees(summary.pnl),
                      style:
                          theme.textTheme.priceLarge.copyWith(color: pnlColor),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        MoneyFormatter.signedPercent(summary.pnlPercent),
                        style: theme.textTheme.change.copyWith(
                          color: pnlColor,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SummaryFigure(
                      label: 'INVESTED',
                      value: MoneyFormatter.rupees(summary.invested),
                    ),
                  ),
                  Expanded(
                    child: _SummaryFigure(
                      label: 'CURRENT',
                      value: MoneyFormatter.rupees(summary.currentValue),
                    ),
                  ),
                  Expanded(
                    child: _SummaryFigure(
                      label: 'CASH',
                      value: MoneyFormatter.rupees(cash),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryFigure extends StatelessWidget {
  const _SummaryFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.columnLabel),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: theme.textTheme.price.copyWith(fontSize: 14)),
        ),
      ],
    );
  }
}
