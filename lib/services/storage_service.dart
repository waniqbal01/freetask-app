import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  String? get token => _prefs.getString(_tokenKey);

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
  }

  Future<void> saveUser(User user) async {
    await _prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  User? getUser() {
    final data = _prefs.getString(_userKey);
    if (data == null) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(data) as Map<String, dynamic>;
      return User.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    await _prefs.remove(_userKey);
  }

  Future<void> clearAll() async {
    await Future.wait<void>([
      _prefs.remove(_tokenKey),
      _prefs.remove(_userKey),
    ]);
  }
}
