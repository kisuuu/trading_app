import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/money/money_formatter.dart';
import 'price_flash.dart';
import 'quote_builder.dart';

/// The right-hand numeric block of a market row: last price, then the day's
/// change in rupees and percent.
///
/// Shared verbatim by the market overview and every watchlist, so the two can
/// never render the same symbol differently.
class LivePriceColumn extends StatelessWidget {
  const LivePriceColumn({required this.symbol, super.key});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return QuoteBuilder(
      symbol: symbol,
      builder: (context, quote, _) {
        final changeColor = MarketColors.forChange(quote.change.paise);
        return PriceFlash(
          sequence: quote.sequence,
          direction: quote.direction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                MoneyFormatter.rupees(quote.ltp),
                style: textTheme.price,
              ),
              const SizedBox(height: 2),
              Text(
                '${MoneyFormatter.signedRupees(quote.change)}  '
                '(${MoneyFormatter.signedPercent(quote.changePercent)})',
                style: textTheme.change.copyWith(color: changeColor),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Left-hand identity block: ticker over company name.
class SymbolIdentity extends StatelessWidget {
  const SymbolIdentity({
    required this.symbol,
    required this.name,
    this.subtitle,
    super.key,
  });

  final String symbol;
  final String name;

  /// Optional override for the second line (holdings show "12 shares · avg …").
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          symbol,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        subtitle ??
            Text(
              name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      ],
    );
  }
}

/// Column headings for the dense price tables.
class MarketColumnHeader extends StatelessWidget {
  const MarketColumnHeader({
    this.leading = 'SYMBOL',
    this.trailing = 'LTP / CHG',
    super.key,
  });

  final String leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.columnLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 22, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Flexible(
            child: Text(leading, style: style, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              trailing,
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
