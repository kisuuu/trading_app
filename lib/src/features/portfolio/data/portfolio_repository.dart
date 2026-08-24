import '../../../core/persistence/key_value_store.dart';
import '../domain/portfolio.dart';

/// Persists cash and holdings as one record.
///
/// Writing them together is what guarantees the two can never disagree after a
/// crash: either the whole post-trade state landed, or none of it did.
class PortfolioRepository {
  const PortfolioRepository(this._store);

  static const String _key = 'portfolio.v1';

  final KeyValueStore _store;

  Portfolio load() => Portfolio.fromJson(_store.readJsonObject(_key));

  Future<void> save(Portfolio portfolio) =>
      _store.writeJson(_key, portfolio.toJson());
}
