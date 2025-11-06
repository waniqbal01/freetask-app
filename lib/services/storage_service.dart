import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/app_theme_mode.dart';
import '../models/user.dart';
import 'key_value_store.dart';

class StorageService {
  StorageService(this._store, {FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage() {
    _hydrateFromStore();
    unawaited(_loadSecureValues());
  }

  final KeyValueStore _store;
  final FlutterSecureStorage _secure;

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _tokenExpiryKey = 'auth_token_expiry';
  static const _roleKey = 'auth_role';
  static const _themeModeKey = 'app_theme_mode';
  static const _jobFeedPrefix = 'cache:job_feed:';

  String? _tokenCache;
  String? _refreshTokenCache;
  DateTime? _tokenExpiryCache;
  String? _userCache;
  String? _roleCache;

  void _hydrateFromStore() {
    _tokenCache = _store.getString(_tokenKey);
    _refreshTokenCache = _store.getString(_refreshTokenKey);
    final expiryRaw = _store.getString(_tokenExpiryKey);
    if (expiryRaw != null) {
      try {
        _tokenExpiryCache = DateTime.parse(expiryRaw).toLocal();
      } catch (_) {
        _tokenExpiryCache = null;
      }
    }
    _userCache = _store.getString(_userKey);
    _roleCache = _store.getString(_roleKey);
  }

  Future<void> _loadSecureValues() async {
    try {
      final token = await _secure.read(key: _tokenKey);
      if (token != null) {
        _tokenCache = token;
      }
      final refreshToken = await _secure.read(key: _refreshTokenKey);
      if (refreshToken != null) {
        _refreshTokenCache = refreshToken;
      }
      final expiry = await _secure.read(key: _tokenExpiryKey);
      if (expiry != null) {
        try {
          _tokenExpiryCache = DateTime.parse(expiry).toLocal();
        } catch (_) {
          _tokenExpiryCache = null;
        }
      }
      final user = await _secure.read(key: _userKey);
      if (user != null) {
        _userCache = user;
      }
      final role = await _secure.read(key: _roleKey);
      if (role != null) {
        _roleCache = role;
      }
    } catch (_) {}

    await Future.wait([
      _store.remove(_tokenKey),
      _store.remove(_refreshTokenKey),
      _store.remove(_tokenExpiryKey),
      _store.remove(_userKey),
      _store.remove(_roleKey),
    ]);
  }

  Future<void> saveToken(String token) async {
    _tokenCache = token;
    await _secure.write(key: _tokenKey, value: token);
    await _store.remove(_tokenKey);
  }

  String? get token => _tokenCache;

  Future<void> clearToken() async {
    _tokenCache = null;
    await Future.wait([
      _secure.delete(key: _tokenKey),
      _store.remove(_tokenKey),
    ]);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    _refreshTokenCache = refreshToken;
    await _secure.write(key: _refreshTokenKey, value: refreshToken);
    await _store.remove(_refreshTokenKey);
  }

  String? get refreshToken => _refreshTokenCache;

  Future<void> clearRefreshToken() async {
    _refreshTokenCache = null;
    await Future.wait([
      _secure.delete(key: _refreshTokenKey),
      _store.remove(_refreshTokenKey),
    ]);
  }

  Future<void> saveTokenExpiry(DateTime? expiry) async {
    if (expiry == null) {
      _tokenExpiryCache = null;
      await Future.wait([
        _secure.delete(key: _tokenExpiryKey),
        _store.remove(_tokenExpiryKey),
      ]);
      return;
    }
    _tokenExpiryCache = expiry.toLocal();
    await _secure.write(
      key: _tokenExpiryKey,
      value: expiry.toUtc().toIso8601String(),
    );
    await _store.remove(_tokenExpiryKey);
  }

  DateTime? get tokenExpiry {
    return _tokenExpiryCache;
  }

  Future<void> clearTokenExpiry() async {
    _tokenExpiryCache = null;
    await Future.wait([
      _secure.delete(key: _tokenExpiryKey),
      _store.remove(_tokenExpiryKey),
    ]);
  }

  Future<void> saveUser(User user) async {
    final encoded = jsonEncode(user.toJson());
    _userCache = encoded;
    await _secure.write(key: _userKey, value: encoded);
    await _store.remove(_userKey);
    await saveRole(user.role);
  }

  User? getUser() {
    final data = _userCache;
    if (data == null) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(data) as Map<String, dynamic>;
      return User.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearUser() async {
    _userCache = null;
    await Future.wait([
      _secure.delete(key: _userKey),
      _store.remove(_userKey),
    ]);
    await clearRole();
  }

  Future<void> saveRole(String role) async {
    _roleCache = role;
    await _secure.write(key: _roleKey, value: role);
    await _store.remove(_roleKey);
  }

  String? get role => _roleCache;

  Future<void> clearRole() async {
    _roleCache = null;
    await Future.wait([
      _secure.delete(key: _roleKey),
      _store.remove(_roleKey),
    ]);
  }

  Future<void> clearAll() async {
    _tokenCache = null;
    _refreshTokenCache = null;
    _tokenExpiryCache = null;
    _userCache = null;
    _roleCache = null;
    await Future.wait([
      _secure.delete(key: _tokenKey),
      _secure.delete(key: _userKey),
      _secure.delete(key: _refreshTokenKey),
      _secure.delete(key: _tokenExpiryKey),
      _secure.delete(key: _roleKey),
      _store.remove(_tokenKey),
      _store.remove(_userKey),
      _store.remove(_refreshTokenKey),
      _store.remove(_tokenExpiryKey),
      _store.remove(_roleKey),
      _store.remove(_themeModeKey),
    ]);
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    await _store.setString(_themeModeKey, mode.name);
  }

  AppThemeMode? getThemeMode() {
    final value = _store.getString(_themeModeKey);
    if (value == null) return null;
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> cacheJobFeed(
    String cacheKey,
    List<Map<String, dynamic>> jobs,
    DateTime timestamp, {
    required int page,
    required int pageSize,
    required int total,
  }) async {
    final key = _buildJobFeedKey(cacheKey);
    final payload = jsonEncode({
      'timestamp': timestamp.toIso8601String(),
      'jobs': jobs,
      'page': page,
      'pageSize': pageSize,
      'total': total,
    });
    await _store.setString(key, payload);
  }

  JobFeedCache? getCachedJobFeed(String cacheKey) {
    final key = _buildJobFeedKey(cacheKey);
    final raw = _store.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final timestamp = DateTime.tryParse(decoded['timestamp']?.toString() ?? '');
      final jobs = (decoded['jobs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      if (timestamp == null) return null;
      final page = decoded['page'] is int
          ? decoded['page'] as int
          : int.tryParse(decoded['page']?.toString() ?? '1') ?? 1;
      final pageSize = decoded['pageSize'] is int
          ? decoded['pageSize'] as int
          : int.tryParse(decoded['pageSize']?.toString() ?? '20') ?? 20;
      final total = decoded['total'] is int
          ? decoded['total'] as int
          : int.tryParse(decoded['total']?.toString() ?? '${jobs.length}') ??
              jobs.length;
      return JobFeedCache(
        timestamp: timestamp.toLocal(),
        jobs: jobs,
        page: page,
        pageSize: pageSize,
        total: total,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedJobFeed(String cacheKey) async {
    final key = _buildJobFeedKey(cacheKey);
    await _store.remove(key);
  }

  String _buildJobFeedKey(String cacheKey) => '$_jobFeedPrefix$cacheKey';
}

class JobFeedCache {
  const JobFeedCache({
    required this.timestamp,
    required this.jobs,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final DateTime timestamp;
  final List<Map<String, dynamic>> jobs;
  final int page;
  final int pageSize;
  final int total;

  bool isFresh(Duration maxAge) {
    return DateTime.now().difference(timestamp) <= maxAge;
  }
}
