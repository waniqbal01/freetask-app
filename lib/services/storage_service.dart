import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _tokenExpiryKey = 'auth_token_expiry';
  static const _roleKey = 'auth_role';
  static const _themeModeKey = 'app_theme_mode';

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
    await saveRole(user.role);
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
    await clearRole();
  }

  Future<void> saveRole(String role) async {
    await _prefs.setString(_roleKey, role);
  }

  String? get role => _prefs.getString(_roleKey);

  Future<void> clearRole() async {
    await _prefs.remove(_roleKey);
  }

  Future<void> clearAll() async {
    await Future.wait<void>([
      _prefs.remove(_tokenKey),
      _prefs.remove(_userKey),
      _prefs.remove(_refreshTokenKey),
      _prefs.remove(_tokenExpiryKey),
      _prefs.remove(_roleKey),
      _prefs.remove(_themeModeKey),
    ]);
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  ThemeMode? getThemeMode() {
    final value = _prefs.getString(_themeModeKey);
    if (value == null) return null;
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
