import 'package:shared_preferences/shared_preferences.dart';

import '../services/key_value_store.dart';

/// Bridges [SharedPreferences] from Flutter into the [KeyValueStore]
/// abstraction used by the pure Dart services.
class SharedPrefsStore implements KeyValueStore {
  SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  /// Creates a [SharedPrefsStore] by obtaining the default
  /// [SharedPreferences] instance. In Flutter applications this should be
  /// awaited during bootstrap before any services are used.
  static Future<SharedPrefsStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPrefsStore(prefs);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
