import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../../market/domain/stock.dart';
import '../../portfolio/domain/holding.dart';
import '../../portfolio/domain/portfolio.dart';
import 'order_failure.dart';
import 'trade_order.dart';

/// A validated, submittable order request.
@immutable
class OrderDraft {
  const OrderDraft({
    required this.symbol,
    required this.side,
    required this.quantity,
  });

  final String symbol;
  final OrderSide side;
  final int quantity;
}

/// Outcome of submitting an order.
@immutable
sealed class OrderResult {
  const OrderResult();
}

final class OrderFilled extends OrderResult {
  const OrderFilled({required this.order, required this.portfolio});

  final TradeOrder order;

  /// The portfolio *after* the fill. Cash and holdings move together.
  final Portfolio portfolio;
}

final class OrderRejected extends OrderResult {
  const OrderRejected(this.failure);

  final OrderFailure failure;
}

/// Pure order-matching logic: given a portfolio, a draft and a fill price, work
/// out whether the order is allowed and what the portfolio becomes.
///
/// Deliberately free of Flutter, storage and clocks (the timestamp and id are
/// passed in) so the rules can be exercised directly in unit tests without a
/// running app.
abstract final class OrderExecutor {
  /// Upper bound on a single order. Guards against a pasted 20-digit quantity
  /// overflowing the arithmetic before the balance check can reject it.
  static const int maxQuantity = 1000000;

  /// Parses user text into a share count, distinguishing *why* it failed so the
  /// form can say something more useful than "invalid".
  static (int?, OrderFailure?) parseQuantity(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return (null, const InvalidQuantity(QuantityRejection.empty));
    }
    final asInt = int.tryParse(text);
    if (asInt == null) {
      // Distinguish "2.5" (a real number, just not whole) from "abc".
      final asNumber = double.tryParse(text);
      if (asNumber == null || !asNumber.isFinite) {
        return (null, const InvalidQuantity(QuantityRejection.notANumber));
      }
      if (asNumber <= 0) {
        return (null, const InvalidQuantity(QuantityRejection.notPositive));
      }
      return (null, const InvalidQuantity(QuantityRejection.fractional));
    }
    if (asInt <= 0) {
      return (null, const InvalidQuantity(QuantityRejection.notPositive));
    }
    if (asInt > maxQuantity) {
      return (null, const InvalidQuantity(QuantityRejection.tooLarge));
    }
    return (asInt, null);
  }

  /// Checks a draft against the portfolio without executing it.
  ///
  /// The ticket calls this on every keystroke and on every price tick to keep
  /// the inline error and the submit button honest; [execute] calls it again at
  /// submission time so a stale UI can never push through an invalid order.
  static OrderFailure? validate({
    required Portfolio portfolio,
    required OrderDraft draft,
    required Money price,
  }) {
    if (!StockUniverse.contains(draft.symbol)) {
      return UnknownSymbol(draft.symbol);
    }
    if (draft.quantity <= 0) {
      return const InvalidQuantity(QuantityRejection.notPositive);
    }
    if (draft.quantity > maxQuantity) {
      return const InvalidQuantity(QuantityRejection.tooLarge);
    }
    if (!price.isPositive) {
      return PriceUnavailable(draft.symbol);
    }

    switch (draft.side) {
      case OrderSide.buy:
        final value = price * draft.quantity;
        if (value > portfolio.cash) {
          return InsufficientFunds(required: value, available: portfolio.cash);
        }
      case OrderSide.sell:
        final held = portfolio.quantityHeld(draft.symbol);
        if (draft.quantity > held) {
          return InsufficientQuantityHeld(
            requested: draft.quantity,
            held: held,
          );
        }
    }
    return null;
  }

  /// Executes [draft] at [price] — the LTP sampled at the moment of submission.
  static OrderResult execute({
    required Portfolio portfolio,
    required OrderDraft draft,
    required Money price,
    required String orderId,
    required DateTime placedAt,
  }) {
    final failure = validate(
      portfolio: portfolio,
      draft: draft,
      price: price,
    );
    if (failure != null) return OrderRejected(failure);

    final value = price * draft.quantity;
    final existing = portfolio.holdingOf(draft.symbol);

    final updated = switch (draft.side) {
      OrderSide.buy => portfolio
          .copyWith(cash: portfolio.cash - value)
          .withHolding(
            draft.symbol,
            existing == null
                ? Holding.opened(
                    symbol: draft.symbol,
                    quantity: draft.quantity,
                    price: price,
                  )
                : existing.applyBuy(quantity: draft.quantity, price: price),
          ),
      OrderSide.sell => portfolio
          .copyWith(cash: portfolio.cash + value)
          .withHolding(
            draft.symbol,
            // `existing` is non-null here: validate() rejected any sell beyond
            // the held quantity, and holding zero rejects every sell.
            existing!.applySell(quantity: draft.quantity),
          ),
    };

    return OrderFilled(
      order: TradeOrder(
        id: orderId,
        symbol: draft.symbol,
        side: draft.side,
        quantity: draft.quantity,
        price: price,
        placedAt: placedAt,
      ),
      portfolio: updated,
    );
  }
}
