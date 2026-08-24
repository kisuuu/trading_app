import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/src/core/persistence/key_value_store.dart';
import 'package:trading_app/src/features/watchlist/data/watchlist_repository.dart';
import 'package:trading_app/src/features/watchlist/domain/watchlist.dart';

Watchlist listOf(List<String> symbols) =>
    Watchlist(id: 'wl-1', name: 'Test', symbols: symbols);

void main() {
  group('membership', () {
    test('adds a symbol once', () {
      final watchlist = listOf(const <String>['RELIANCE'])
          .withSymbolAdded('TCS')
          .withSymbolAdded('TCS');
      expect(watchlist.symbols, <String>['RELIANCE', 'TCS']);
    });

    test('ignores symbols outside the universe', () {
      final watchlist = listOf(const <String>[]).withSymbolAdded('NOTREAL');
      expect(watchlist.symbols, isEmpty);
    });

    test('removes a symbol and leaves the rest in order', () {
      final watchlist =
          listOf(const <String>['RELIANCE', 'TCS', 'INFY']).withSymbolRemoved('TCS');
      expect(watchlist.symbols, <String>['RELIANCE', 'INFY']);
    });

    test('restores a removed symbol at its original index', () {
      final watchlist = listOf(const <String>['RELIANCE', 'INFY'])
          .withSymbolInserted('TCS', 1);
      expect(watchlist.symbols, <String>['RELIANCE', 'TCS', 'INFY']);
    });
  });

  group('reordering', () {
    // ReorderableListView reports a destination index that still counts the
    // dragged item when moving down, which is the off-by-one this covers.
    test('moves an item down', () {
      final watchlist =
          listOf(const <String>['A', 'B', 'C']).withSymbolMoved(0, 2);
      expect(watchlist.symbols, <String>['B', 'A', 'C']);
    });

    test('moves an item up', () {
      final watchlist =
          listOf(const <String>['A', 'B', 'C']).withSymbolMoved(2, 0);
      expect(watchlist.symbols, <String>['C', 'A', 'B']);
    });

    test('moving to the end keeps every symbol', () {
      final watchlist =
          listOf(const <String>['A', 'B', 'C']).withSymbolMoved(0, 3);
      expect(watchlist.symbols, <String>['B', 'C', 'A']);
    });

    test('a drag that lands where it started is a no-op', () {
      final original = listOf(const <String>['A', 'B', 'C']);
      expect(identical(original.withSymbolMoved(1, 1), original), isTrue);
      expect(identical(original.withSymbolMoved(9, 0), original), isTrue);
    });
  });

  group('persistence', () {
    late InMemoryKeyValueStore store;
    late WatchlistRepository repository;

    setUp(() {
      store = InMemoryKeyValueStore();
      repository = WatchlistRepository(store);
    });

    test('round-trips watchlists including their order', () async {
      final saved = <Watchlist>[
        const Watchlist(
          id: 'a',
          name: 'Banking',
          symbols: <String>['HDFCBANK', 'ICICIBANK', 'SBIN'],
        ),
        const Watchlist(id: 'b', name: 'IT', symbols: <String>['TCS', 'INFY']),
      ];
      await repository.save(saved);
      await repository.saveSelectedId('b');

      final restored = repository.load();
      expect(restored, hasLength(2));
      expect(restored.first.name, 'Banking');
      expect(
        restored.first.symbols,
        <String>['HDFCBANK', 'ICICIBANK', 'SBIN'],
      );
      expect(repository.loadSelectedId(), 'b');
    });

    test('a removed symbol stays gone after a restart', () async {
      await repository.save(<Watchlist>[
        listOf(const <String>['RELIANCE', 'TCS']).withSymbolRemoved('TCS'),
      ]);
      expect(repository.load().single.symbols, <String>['RELIANCE']);
    });

    test('drops symbols that are no longer in the universe', () async {
      await store.writeString(
        'watchlists.v1',
        '[{"id":"a","name":"Old","symbols":["RELIANCE","DELISTED"]}]',
      );
      expect(repository.load().single.symbols, <String>['RELIANCE']);
    });

    test('survives a corrupt payload instead of crashing', () async {
      await store.writeString('watchlists.v1', '{not json');
      expect(repository.load(), isEmpty);
    });

    test('skips malformed rows but keeps the good ones', () async {
      await store.writeString(
        'watchlists.v1',
        '[{"id":"a","name":"Good","symbols":["TCS"]},{"name":"No id"},42]',
      );
      final restored = repository.load();
      expect(restored, hasLength(1));
      expect(restored.single.name, 'Good');
    });
  });
}
