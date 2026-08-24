import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'key_value_store.dart';

/// Overridden in `main()` once platform storage has been opened.
///
/// Declaring it as an unimplemented provider makes the dependency explicit: any
/// entry point that forgets to supply a store fails loudly at startup rather
/// than silently losing the user's data.
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError('keyValueStoreProvider must be overridden'),
);
