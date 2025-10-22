import '../models/auth_response.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.token,
    this.refreshToken,
    this.expiresAt,
  });

  final User user;
  final String token;
  final String? refreshToken;
  final DateTime? expiresAt;

  factory AuthSession.fromResponse(AuthResponse response) {
    return AuthSession(
      user: response.user,
      token: response.token,
      refreshToken: response.refreshToken,
      expiresAt: response.expiresAt,
    );
  }
}

class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required StorageService storage,
  })  : _authService = authService,
        _storage = storage;

  final AuthService _authService;
  final StorageService _storage;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _authService.login(email: email, password: password);
    return AuthSession.fromResponse(response);
  }

  Future<AuthSession> signup({
    required String name,
    required String email,
    required String password,
    String role = 'client',
  }) async {
    final response = await _authService.signup(
      name: name,
      email: email,
      password: password,
      role: role,
    );
    return AuthSession.fromResponse(response);
  }

  Future<AuthSession?> restoreSession() async {
    final token = _storage.token;
    if (token == null || token.isEmpty) {
      return null;
    }

    final valid = await _ensureValidToken();
    if (!valid) {
      return null;
    }

    final cachedUser = _storage.getUser();
    if (cachedUser != null) {
      return AuthSession(
        user: cachedUser,
        token: _storage.token ?? token,
        refreshToken: _storage.refreshToken,
        expiresAt: _storage.tokenExpiry,
      );
    }

    final user = await _authService.fetchMe();
    return AuthSession(
      user: user,
      token: _storage.token ?? token,
      refreshToken: _storage.refreshToken,
      expiresAt: _storage.tokenExpiry,
    );
  }

  Future<User> fetchCurrentUser() => _authService.fetchMe();

  Future<void> logout() async {
    try {
      await _authService.logout();
    } finally {
      await _storage.clearAll();
    }
  }

  Future<void> requestPasswordReset(String email) {
    return _authService.requestPasswordReset(email);
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String token,
    required String password,
  }) {
    return _authService.confirmPasswordReset(
      email: email,
      token: token,
      password: password,
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) {
    return _authService.verifyEmail(email: email, code: code);
  }

  Future<bool> _ensureValidToken() async {
    final expiry = _storage.tokenExpiry;
    if (expiry == null) {
      return true;
    }

    final now = DateTime.now();
    if (expiry.isAfter(now.add(const Duration(minutes: 1)))) {
      return true;
    }

    try {
      await _authService.refreshToken();
      return true;
    } on AuthException catch (error, stackTrace) {
      AppLogger.e('Token refresh failed', error: error, stackTrace: stackTrace);
      await _storage.clearAll();
      return false;
    } catch (error, stackTrace) {
      AppLogger.e('Unexpected error refreshing token', error: error, stackTrace: stackTrace);
      await _storage.clearAll();
      return false;
    }
  }
}
