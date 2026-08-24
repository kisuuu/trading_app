import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../application/market_providers.dart';
import '../../data/market_feed.dart';
import '../../domain/stock.dart';

/// Debug surface for the mock feed: change the tick rate and watch what the
/// coalescing pipeline does with it.
///
/// The two counters are the point of this sheet. Raising the rate multiplies
/// *ticks in*, while *UI flushes* stays pinned at the frame rate — which is the
/// whole reason the app stays smooth at 250 ticks/sec.
class FeedSettingsSheet extends ConsumerWidget {
  const FeedSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const FeedSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rate = ref.watch(tickRateProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Market feed', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tick rate per stock. The feed drives every price in the app.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<TickRate>(
              segments: <ButtonSegment<TickRate>>[
                for (final option in TickRate.values)
                  ButtonSegment<TickRate>(
                    value: option,
                    label: Text(option.label),
                  ),
              ],
              selected: <TickRate>{rate},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(tickRateProvider.notifier).set(selection.first),
            ),
            const SizedBox(height: 12),
            Text(
              '${rate.ticksPerSecondPerSymbol}/sec per stock  ·  '
              '${rate.totalTicksPerSecond(StockUniverse.stocks.length)}/sec '
              'across the universe',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            const _ThroughputMeter(),
          ],
        ),
      ),
    );
  }
}

/// Samples the service's counters once a second and shows ticks in vs. UI
/// updates out.
class _ThroughputMeter extends ConsumerStatefulWidget {
  const _ThroughputMeter();

  @override
  ConsumerState<_ThroughputMeter> createState() => _ThroughputMeterState();
}

class _ThroughputMeterState extends ConsumerState<_ThroughputMeter> {
  Timer? _timer;
  int _lastTicks = 0;
  int _lastFlushes = 0;
  int _ticksPerSecond = 0;
  int _flushesPerSecond = 0;

  @override
  void initState() {
    super.initState();
    final market = ref.read(marketDataServiceProvider);
    _lastTicks = market.ticksReceived;
    _lastFlushes = market.flushCount;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _ticksPerSecond = market.ticksReceived - _lastTicks;
        _flushesPerSecond = market.flushCount - _lastFlushes;
        _lastTicks = market.ticksReceived;
        _lastFlushes = market.flushCount;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _Metric(
            label: 'TICKS IN',
            value: '$_ticksPerSecond/s',
            color: MarketColors.up,
          ),
        ),
        Expanded(
          child: _Metric(
            label: 'UI FLUSHES',
            value: '$_flushesPerSecond/s',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.columnLabel),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.priceLarge.copyWith(
            fontSize: 22,
            color: color,
          ),
        ),
      ],
    );
  }
}
