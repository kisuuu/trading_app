import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids.dart';
import '../../../core/persistence/store_provider.dart';
import '../../market/domain/stock.dart';
import '../data/watchlist_repository.dart';
import '../domain/watchlist.dart';

final Provider<WatchlistRepository> watchlistRepositoryProvider =
    Provider<WatchlistRepository>(
  (ref) => WatchlistRepository(ref.watch(keyValueStoreProvider)),
);

@immutable
class WatchlistState {
  const WatchlistState({required this.watchlists, required this.selectedId});

  final List<Watchlist> watchlists;

  /// `null` only when the user has deleted every list.
  final String? selectedId;

  bool get isEmpty => watchlists.isEmpty;

  Watchlist? byId(String id) {
    for (final watchlist in watchlists) {
      if (watchlist.id == id) return watchlist;
    }
    return null;
  }

  Watchlist? get selected {
    final id = selectedId;
    final match = id == null ? null : byId(id);
    if (match != null) return match;
    return watchlists.isEmpty ? null : watchlists.first;
  }

  int get selectedIndex {
    final current = selected;
    if (current == null) return 0;
    return watchlists.indexOf(current);
  }
}

/// Owns watchlist creation, naming, membership and ordering.
///
/// State is restored synchronously in [build] — `SharedPreferences` is already
/// warm by the time the widget tree exists — so screens never render a spinner
/// for data that is, in practice, always available.
class WatchlistController extends Notifier<WatchlistState> {
  /// Seeded on a genuinely fresh install so the app opens onto something
  /// useful. Distinct from "the user deleted all their lists", which is
  /// preserved as-is.
  static const List<String> _seedSymbols = <String>[
    'RELIANCE',
    'TCS',
    'INFY',
    'HDFCBANK',
    'ICICIBANK',
  ];

  late final WatchlistRepository _repository;

  @override
  WatchlistState build() {
    _repository = ref.watch(watchlistRepositoryProvider);
    final stored = _repository.load();

    if (stored.isEmpty && _repository.loadSelectedId() == null) {
      final seeded = Watchlist(
        id: Ids.next('wl'),
        name: 'My Watchlist',
        symbols: _seedSymbols,
      );
      _persist(<Watchlist>[seeded], seeded.id);
      return WatchlistState(
        watchlists: <Watchlist>[seeded],
        selectedId: seeded.id,
      );
    }

    final selectedId = _repository.loadSelectedId();
    return WatchlistState(
      watchlists: stored,
      selectedId: stored.any((w) => w.id == selectedId)
          ? selectedId
          : (stored.isEmpty ? null : stored.first.id),
    );
  }

  String createWatchlist(String name) {
    final watchlist = Watchlist(
      id: Ids.next('wl'),
      name: _sanitiseName(name),
      symbols: const <String>[],
    );
    _apply(<Watchlist>[...state.watchlists, watchlist], watchlist.id);
    return watchlist.id;
  }

  void renameWatchlist(String id, String name) {
    _updateOne(id, (watchlist) => watchlist.copyWith(name: _sanitiseName(name)));
  }

  void deleteWatchlist(String id) {
    final remaining = <Watchlist>[
      for (final watchlist in state.watchlists)
        if (watchlist.id != id) watchlist,
    ];
    if (remaining.length == state.watchlists.length) return;
    // Deleting the active list falls back to the first survivor, or to no
    // selection at all once nothing is left.
    final selectedId = state.selectedId == id
        ? (remaining.isEmpty ? null : remaining.first.id)
        : state.selectedId;
    _apply(remaining, selectedId);
  }

  void select(String id) {
    if (state.selectedId == id) return;
    _apply(state.watchlists, id);
  }

  void addSymbol(String watchlistId, String symbol) {
    if (!StockUniverse.contains(symbol)) return;
    _updateOne(watchlistId, (watchlist) => watchlist.withSymbolAdded(symbol));
  }

  void removeSymbol(String watchlistId, String symbol) {
    _updateOne(watchlistId, (watchlist) => watchlist.withSymbolRemoved(symbol));
  }

  void insertSymbol(String watchlistId, String symbol, int index) {
    if (!StockUniverse.contains(symbol)) return;
    _updateOne(
      watchlistId,
      (watchlist) => watchlist.withSymbolInserted(symbol, index),
    );
  }

  void reorder(String watchlistId, int oldIndex, int newIndex) {
    _updateOne(
      watchlistId,
      (watchlist) => watchlist.withSymbolMoved(oldIndex, newIndex),
    );
  }

  /// Toggles membership — used by the stock picker's rows.
  void toggleSymbol(String watchlistId, String symbol) {
    _updateOne(
      watchlistId,
      (watchlist) => watchlist.contains(symbol)
          ? watchlist.withSymbolRemoved(symbol)
          : watchlist.withSymbolAdded(symbol),
    );
  }

  /// Replaces a single watchlist in place, skipping the write entirely when the
  /// transform was a no-op (dragging a row back where it started, re-adding a
  /// symbol that is already present).
  void _updateOne(String id, Watchlist Function(Watchlist) transform) {
    final index = state.watchlists.indexWhere((w) => w.id == id);
    if (index < 0) return;
    final current = state.watchlists[index];
    final updated = transform(current);
    if (identical(updated, current)) return;
    _apply(
      List<Watchlist>.of(state.watchlists)..[index] = updated,
      state.selectedId,
    );
  }

  void _apply(List<Watchlist> watchlists, String? selectedId) {
    state = WatchlistState(watchlists: watchlists, selectedId: selectedId);
    _persist(watchlists, selectedId);
  }

  /// Writes are fire-and-forget: the UI has already moved on, and a failed
  /// write must not take the app down. Losing persistence is logged, not fatal.
  void _persist(List<Watchlist> watchlists, String? selectedId) {
    _repository.save(watchlists).catchError(
          (Object error) => debugPrint('Failed to save watchlists: $error'),
        );
    if (selectedId != null) {
      _repository.saveSelectedId(selectedId).catchError(
            (Object error) => debugPrint('Failed to save selection: $error'),
          );
    }
  }

  static String _sanitiseName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Untitled';
    return trimmed.length > 40 ? trimmed.substring(0, 40) : trimmed;
  }
}

final NotifierProvider<WatchlistController, WatchlistState>
    watchlistControllerProvider =
    NotifierProvider<WatchlistController, WatchlistState>(
  WatchlistController.new,
);
