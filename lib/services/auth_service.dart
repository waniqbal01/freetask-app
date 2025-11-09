import 'package:dio/dio.dart';

import '../models/auth_response.dart';
import '../models/user.dart';
import '../models/user_roles.dart';
import 'session_api_client.dart';
import 'storage_service.dart';

class AuthService {
  AuthService(
    this._apiClient,
    this._storage,
  ) {
    _apiClient.setRefreshCallback(refreshToken);
  }

  final SessionApiClient _apiClient;
  final StorageService _storage;

  Dio get _http => _apiClient.client;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _http.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {
          'email': email,
          'password': password,
        },
        options: _apiClient.guard(requiresAuth: false),
      );

      return _persistAuthResponse(response.data);
    } on DioException catch (error) {
      throw AuthException(
        _extractErrorMessage(error, 'Unable to sign in. Please try again.'),
      );
    } catch (_) {
      throw AuthException('Unable to sign in. Please try again.');
    }
  }

  Future<AuthResponse> signup({
    required String name,
    required String email,
    required String password,
    String role = kDefaultUserRoleName,
  }) async {
    try {
      final response = await _http.post<Map<String, dynamic>>(
        '/api/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        },
        options: _apiClient.guard(requiresAuth: false),
      );

      final authResponse = await _persistAuthResponse(response.data);
      await _storage.saveRole(authResponse.user.role);
      return authResponse;
    } on DioException catch (error) {
      throw AuthException(
        _extractErrorMessage(
          error,
          'Unable to complete registration. Please try again.',
        ),
      );
    } catch (_) {
      throw AuthException('Unable to complete registration. Please try again.');
    }
  }

  Future<User> fetchMe() async {
    try {
      final response = await _http.get<Map<String, dynamic>>(
        '/api/auth/me',
        options: _apiClient.guard(),
      );

      final data = response.data ?? <String, dynamic>{};
      final payload = (data['user'] is Map<String, dynamic>)
          ? data['user'] as Map<String, dynamic>
          : data;
      final user = User.fromJson(payload);
      await _storage.saveUser(user);
      await _storage.saveRole(user.role);
      return user;
    } on DioException catch (error) {
      throw AuthException(
        _extractErrorMessage(error, 'Failed to load account information.'),
      );
    } catch (_) {
      throw AuthException('Failed to load account information.');
    }
  }

  Future<void> logout() async {
    final refreshToken = _storage.refreshToken;
    try {
      await _http.post<void>(
        '/api/auth/logout',
        data: {
          if (refreshToken != null && refreshToken.isNotEmpty)
            'refreshToken': refreshToken,
        },
        options: _apiClient.guard(requiresAuth: false),
      );
    } catch (_) {
      // Ignore logout failures – session will be cleared locally regardless.
    } finally {
      await _storage.clearAll();
    }
  }

  Future<String> refreshToken() async {
    final refreshToken = _storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw AuthException('Unable to refresh authentication token.');
    }

    try {
      final response = await _http.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: _apiClient.guard(requiresAuth: false),
      );

      final authResponse = await _persistAuthResponse(response.data);
      return authResponse.token;
    } on DioException catch (error) {
      throw AuthException(
        _extractErrorMessage(
          error,
          'Unable to refresh authentication token.',
        ),
      );
    } catch (_) {
      throw AuthException('Unable to refresh authentication token.');
    }
  }

  Future<void> requestPasswordReset(String email) async {
    throw AuthException(
      'Password reset via email is not supported in this environment.',
    );
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String token,
    required String password,
  }) async {
    throw AuthException(
      'Password reset confirmation is not supported in this environment.',
    );
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    throw AuthException('Email verification is not supported.');
  }

  Future<AuthResponse> _persistAuthResponse(Map<String, dynamic>? data) async {
    final payload = data ?? <String, dynamic>{};
    final response = AuthResponse.fromJson(payload);

    if (response.token.isEmpty) {
      throw AuthException('Missing authentication token. Please try again.');
    }

    await _storage.saveToken(response.token);
    await _storage.saveUser(response.user);
    await _storage.saveRole(response.user.role);

    if (response.refreshToken != null && response.refreshToken!.isNotEmpty) {
      await _storage.saveRefreshToken(response.refreshToken!);
    } else {
      await _storage.clearRefreshToken();
    }

    await _storage.saveTokenExpiry(response.expiresAt);

    return response;
  }

  String _extractErrorMessage(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return fallback;
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
