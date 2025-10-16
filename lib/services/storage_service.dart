import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _tokenExpiryKey = 'auth_token_expiry';

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  String? get token => _prefs.getString(_tokenKey);

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _prefs.setString(_refreshTokenKey, refreshToken);
  }

  String? get refreshToken => _prefs.getString(_refreshTokenKey);

  Future<void> clearRefreshToken() async {
    await _prefs.remove(_refreshTokenKey);
  }

  Future<void> saveTokenExpiry(DateTime? expiry) async {
    if (expiry == null) {
      await _prefs.remove(_tokenExpiryKey);
      return;
    }
    await _prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
  }

  DateTime? get tokenExpiry {
    final value = _prefs.getString(_tokenExpiryKey);
    if (value == null) return null;
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTokenExpiry() async {
    await _prefs.remove(_tokenExpiryKey);
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
      _prefs.remove(_refreshTokenKey),
      _prefs.remove(_tokenExpiryKey),
    ]);
  }
}
