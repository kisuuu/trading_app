import 'package:meta/meta.dart';

import '../../market/domain/stock.dart';

/// A named, ordered list of symbols.
///
/// Order is user-controlled (drag to reorder) and part of the persisted state,
/// so the list looks exactly the same after a restart.
@immutable
class Watchlist {
  const Watchlist({
    required this.id,
    required this.name,
    required this.symbols,
  });

  final String id;
  final String name;
  final List<String> symbols;

  bool get isEmpty => symbols.isEmpty;

  int get length => symbols.length;

  bool contains(String symbol) => symbols.contains(symbol);

  Watchlist copyWith({String? name, List<String>? symbols}) {
    return Watchlist(
      id: id,
      name: name ?? this.name,
      symbols: symbols ?? this.symbols,
    );
  }

  /// Appends [symbol] unless it is already present — a watchlist is a set with
  /// a user-defined order, never a bag with duplicates.
  Watchlist withSymbolAdded(String symbol) {
    if (contains(symbol) || !StockUniverse.contains(symbol)) return this;
    return copyWith(symbols: <String>[...symbols, symbol]);
  }

  /// Inserts [symbol] at [index] — used to undo a removal, putting the row
  /// back exactly where the user had it rather than at the end.
  Watchlist withSymbolInserted(String symbol, int index) {
    if (contains(symbol) || !StockUniverse.contains(symbol)) return this;
    final next = List<String>.of(symbols)
      ..insert(index.clamp(0, symbols.length), symbol);
    return copyWith(symbols: next);
  }

  Watchlist withSymbolRemoved(String symbol) {
    if (!contains(symbol)) return this;
    return copyWith(
      symbols: <String>[
        for (final existing in symbols)
          if (existing != symbol) existing,
      ],
    );
  }

  /// Moves the symbol at [oldIndex] to [newIndex] using `ReorderableListView`
  /// index semantics, where a downward move reports a destination index that
  /// still counts the item being dragged.
  Watchlist withSymbolMoved(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= symbols.length) return this;
    final target = (newIndex > oldIndex ? newIndex - 1 : newIndex)
        .clamp(0, symbols.length - 1);
    if (target == oldIndex) return this;
    final next = List<String>.of(symbols);
    next.insert(target, next.removeAt(oldIndex));
    return copyWith(symbols: next);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'symbols': symbols,
      };

  static Watchlist? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final name = json['name'];
    final symbols = json['symbols'];
    if (id is! String || name is! String) return null;
    return Watchlist(
      id: id,
      name: name,
      symbols: <String>[
        // Drop anything no longer in the universe rather than rendering a row
        // that can never receive a price.
        if (symbols is List<Object?>)
          for (final symbol in symbols)
            if (symbol is String && StockUniverse.contains(symbol)) symbol,
      ],
    );
  }
}
