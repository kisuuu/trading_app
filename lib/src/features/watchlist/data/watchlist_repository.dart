import '../../../core/persistence/key_value_store.dart';
import '../domain/watchlist.dart';

/// Persists watchlists and the user's current selection.
class WatchlistRepository {
  const WatchlistRepository(this._store);

  static const String _listsKey = 'watchlists.v1';
  static const String _selectedKey = 'watchlists.selected.v1';

  final KeyValueStore _store;

  /// Restores saved watchlists. Returns an empty list when nothing is stored or
  /// the payload cannot be read; the controller seeds a default in that case.
  List<Watchlist> load() {
    final rows = _store.readJsonArray(_listsKey);
    if (rows == null) return const <Watchlist>[];
    return <Watchlist>[
      for (final row in rows)
        if (Watchlist.fromJson(row) case final Watchlist watchlist) watchlist,
    ];
  }

  String? loadSelectedId() => _store.readString(_selectedKey);

  Future<void> save(List<Watchlist> watchlists) {
    return _store.writeJson(
      _listsKey,
      <Object?>[for (final watchlist in watchlists) watchlist.toJson()],
    );
  }

  Future<void> saveSelectedId(String id) =>
      _store.writeString(_selectedKey, id);
}
