/// A minimal asynchronous key-value store abstraction used by services that
/// previously depended on Flutter's [SharedPreferences]. The interface keeps the
/// existing API surface small so the rest of the codebase can operate in a pure
/// Dart environment.
abstract class KeyValueStore {
  Future<void> setString(String key, String value);
  String? getString(String key);
  Future<void> remove(String key);
}

/// In-memory implementation of [KeyValueStore] suitable for tests and console
/// applications. Values persist for the lifetime of the store instance.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _storage = <String, String>{};

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }

  @override
  String? getString(String key) => _storage[key];

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}
