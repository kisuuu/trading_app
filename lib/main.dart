import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app/app.dart';
import 'src/core/persistence/key_value_store.dart';
import 'src/core/persistence/store_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(await _openStore()),
      ],
      child: const TradingApp(),
    ),
  );
}

/// Opens platform storage, degrading to an in-memory store if it is
/// unavailable.
///
/// A device that cannot give us `SharedPreferences` should still get a working
/// app — it just will not remember anything after a restart. Refusing to launch
/// over a storage fault would be the worse failure.
Future<KeyValueStore> _openStore() async {
  try {
    return SharedPreferencesStore(await SharedPreferences.getInstance());
  } on Object catch (error, stackTrace) {
    debugPrint('Falling back to in-memory storage: $error\n$stackTrace');
    return InMemoryKeyValueStore();
  }
}
