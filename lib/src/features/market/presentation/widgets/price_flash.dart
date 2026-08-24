import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/quote.dart';

/// Briefly tints its child green or red when a new tick arrives.
///
/// Retriggering is keyed on [sequence] rather than on the price, so a trade
/// that prints at the same price still flashes — a flat re-trade is real market
/// activity, and a table that goes still would read as a dead feed.
///
/// Only the tint repaints: the child is passed to [AnimatedBuilder] as a cached
/// subtree, so the price text underneath is not rebuilt 60 times a second while
/// the flash fades.
class PriceFlash extends StatefulWidget {
  const PriceFlash({
    required this.sequence,
    required this.direction,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    super.key,
  });

  static const Duration fadeDuration = Duration(milliseconds: 420);

  final int sequence;
  final TickDirection direction;
  final EdgeInsets padding;
  final Widget child;

  @override
  State<PriceFlash> createState() => _PriceFlashState();
}

class _PriceFlashState extends State<PriceFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PriceFlash.fadeDuration,
  );

  TickDirection _direction = TickDirection.unchanged;

  @override
  void didUpdateWidget(PriceFlash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sequence != oldWidget.sequence &&
        widget.direction != TickDirection.unchanged) {
      _direction = widget.direction;
      // Restart from full intensity even if a previous flash is mid-fade;
      // under a fast feed this keeps the most recent tick the visible one.
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Padding(padding: widget.padding, child: widget.child),
      builder: (context, child) {
        final intensity = 1 - _controller.value;
        final isIdle = _controller.status == AnimationStatus.dismissed;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: isIdle
                ? Colors.transparent
                : (_direction == TickDirection.up
                        ? MarketColors.up
                        : MarketColors.down)
                    .withValues(alpha: 0.22 * intensity),
            borderRadius: BorderRadius.circular(6),
          ),
          child: child,
        );
      },
    );
  }
}
