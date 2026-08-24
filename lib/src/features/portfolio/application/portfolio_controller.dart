import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../core/persistence/store_provider.dart';
import '../data/portfolio_repository.dart';
import '../domain/holding.dart';
import '../domain/portfolio.dart';

final Provider<PortfolioRepository> portfolioRepositoryProvider =
    Provider<PortfolioRepository>(
  (ref) => PortfolioRepository(ref.watch(keyValueStoreProvider)),
);

/// Holds cash and positions. Trades are applied wholesale by [replaceWith] —
/// the executor produces the complete next portfolio, so this controller never
/// re-implements any trading rules.
class PortfolioController extends Notifier<Portfolio> {
  late final PortfolioRepository _repository;

  @override
  Portfolio build() {
    _repository = ref.watch(portfolioRepositoryProvider);
    return _repository.load();
  }

  void replaceWith(Portfolio portfolio) {
    state = portfolio;
    _repository.save(portfolio).catchError(
          (Object error) => debugPrint('Failed to save portfolio: $error'),
        );
  }

  /// Debug affordance: wipes positions and restores the opening balance.
  void reset() => replaceWith(Portfolio.initial);
}

final NotifierProvider<PortfolioController, Portfolio> portfolioControllerProvider =
    NotifierProvider<PortfolioController, Portfolio>(PortfolioController.new);

/// Positions only, as a list. Rebuilds when a trade changes the position set —
/// never on a price tick.
final Provider<List<Holding>> holdingsProvider = Provider<List<Holding>>((ref) {
  return ref.watch(portfolioControllerProvider).holdings.values.toList();
});

/// Available margin.
final Provider<Money> availableCashProvider = Provider<Money>((ref) {
  return ref.watch(portfolioControllerProvider).cash;
});
