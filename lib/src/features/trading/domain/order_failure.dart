import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';

/// Why a quantity input is not tradable.
enum QuantityRejection { empty, notANumber, fractional, notPositive, tooLarge }

/// Every way an order can be refused, as a sealed hierarchy so the UI must
/// handle each case and each carries the numbers needed for a useful message.
@immutable
sealed class OrderFailure {
  const OrderFailure();

  /// Inline, user-facing explanation.
  String get message;
}

final class InvalidQuantity extends OrderFailure {
  const InvalidQuantity(this.reason);

  final QuantityRejection reason;

  @override
  String get message => switch (reason) {
        QuantityRejection.empty => 'Enter a quantity',
        QuantityRejection.notANumber => 'Quantity must be a number',
        QuantityRejection.fractional =>
          'Fractional quantities are not allowed — enter whole shares',
        QuantityRejection.notPositive => 'Quantity must be at least 1',
        QuantityRejection.tooLarge => 'Quantity is too large',
      };
}

final class InsufficientFunds extends OrderFailure {
  const InsufficientFunds({required this.required, required this.available});

  final Money required;
  final Money available;

  Money get shortfall => required - available;

  @override
  String get message =>
      'Order value ${MoneyFormatter.rupees(required)} exceeds your available '
      'balance of ${MoneyFormatter.rupees(available)} '
      '(short by ${MoneyFormatter.rupees(shortfall)})';
}

final class InsufficientQuantityHeld extends OrderFailure {
  const InsufficientQuantityHeld({required this.requested, required this.held});

  final int requested;
  final int held;

  @override
  String get message => held == 0
      ? 'You do not hold any shares of this stock'
      : 'You hold only $held share${held == 1 ? '' : 's'}, cannot sell '
          '$requested';
}

final class UnknownSymbol extends OrderFailure {
  const UnknownSymbol(this.symbol);

  final String symbol;

  @override
  String get message => '$symbol is not available for trading';
}

final class PriceUnavailable extends OrderFailure {
  const PriceUnavailable(this.symbol);

  final String symbol;

  @override
  String get message => 'No live price for $symbol right now — try again';
}
