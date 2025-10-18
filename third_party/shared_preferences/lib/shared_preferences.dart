class SharedPreferences {
  SharedPreferences._();

  static Future<SharedPreferences> getInstance() async {
    return SharedPreferences._();
  }

  final Map<String, Object?> _storage = <String, Object?>{};

  Future<bool> setString(String key, String value) async {
    _storage[key] = value;
    return true;
  }

  String? getString(String key) {
    final value = _storage[key];
    return value is String ? value : null;
  }

  Future<bool> remove(String key) async {
    _storage.remove(key);
    return true;
  }
}
