import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Narrow persistence port used by every repository.
///
/// Reads are synchronous so controllers can hydrate their initial state in
/// their constructor — no `AsyncValue` loading states leaking into screens that
/// conceptually always have data. `SharedPreferences` is loaded once during
/// startup and caches everything in memory, which makes that safe.
abstract interface class KeyValueStore {
  String? readString(String key);

  Future<void> writeString(String key, String value);

  Future<void> remove(String key);
}

/// Convenience JSON helpers shared by all repositories, including the
/// corrupt-payload handling: a value we cannot decode is treated as absent
/// rather than crashing the app on launch.
extension JsonStore on KeyValueStore {
  Map<String, Object?>? readJsonObject(String key) {
    final raw = readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException catch (error) {
      debugPrint('Dropping corrupt payload at "$key": $error');
      return null;
    }
  }

  List<Object?>? readJsonArray(String key) {
    final raw = readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List<Object?> ? decoded : null;
    } on FormatException catch (error) {
      debugPrint('Dropping corrupt payload at "$key": $error');
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) =>
      writeString(key, jsonEncode(value));
}

class SharedPreferencesStore implements KeyValueStore {
  const SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? readString(String key) => _prefs.getString(key);

  @override
  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Fallback used when platform storage is unavailable (and in tests).
///
/// The app stays fully usable; only persistence across restarts is lost, which
/// beats refusing to launch.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  String? readString(String key) => _values[key];

  @override
  Future<void> writeString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
