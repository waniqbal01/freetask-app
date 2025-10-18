import 'package:dio/dio.dart';

import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  AuthService(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final StorageService _storage;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      final data = response.data ?? <String, dynamic>{};
      final authResponse = AuthResponse.fromJson(data);
      await _persistSession(authResponse);
      final user = await fetchMe();
      return AuthResponse(
        token: authResponse.token,
        refreshToken: authResponse.refreshToken,
        expiresAt: authResponse.expiresAt,
        user: user,
      );
    } on DioException catch (error) {
      throw AuthException(_mapError(error));
    }
  }

  Future<AuthResponse> signup({
    required String name,
    required String email,
    required String password,
    String role = 'client',
  }) async {
    try {
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      final data = response.data ?? <String, dynamic>{};
      final authResponse = AuthResponse.fromJson(data);
      await _persistSession(authResponse);
      final user = await fetchMe();
      return AuthResponse(
        token: authResponse.token,
        refreshToken: authResponse.refreshToken,
        expiresAt: authResponse.expiresAt,
        user: user,
      );
    } on DioException catch (error) {
      throw AuthException(_mapError(error));
    }
  }

  Future<User> fetchMe() async {
    try {
      final response = await _apiClient.client.get<Map<String, dynamic>>(
        '/users/me',
      );
      final data = response.data ?? <String, dynamic>{};
      final user = User.fromJson(data);
      await _storage.saveUser(user);
      return user;
    } on DioException catch (error) {
      throw AuthException(_mapError(error));
    }
  }

  Future<void> logout() => _storage.clearAll();

  Future<String> refreshToken() async {
    final refreshToken = _storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _storage.clearAll();
      throw AuthException('Session expired. Please log in again.');
    }

    try {
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: const {'skipAuth': true}),
      );
      final data = response.data ?? <String, dynamic>{};
      final newToken = data['token'] as String? ?? '';
      if (newToken.isEmpty) {
        await _storage.clearAll();
        throw AuthException('Unable to refresh session. Please sign in again.');
      }

      final newRefreshToken =
          data['refreshToken'] as String? ?? data['refresh_token'] as String?;
      final expiresRaw = data['expiresAt'] ?? data['expires_in'];
      DateTime? expiresAt;
      if (expiresRaw is String) {
        expiresAt = DateTime.tryParse(expiresRaw)?.toLocal();
      } else if (expiresRaw is int) {
        expiresAt = DateTime.now().add(Duration(seconds: expiresRaw));
      }

      await _storage.saveToken(newToken);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.saveRefreshToken(newRefreshToken);
      }
      await _storage.saveTokenExpiry(expiresAt);
      return newToken;
    } on DioException catch (error) {
      await _storage.clearAll();
      throw AuthException(_mapError(error));
    }
  }

  Future<void> _persistSession(AuthResponse authResponse) async {
    await _storage.saveToken(authResponse.token);
    if ((authResponse.refreshToken ?? '').isNotEmpty) {
      await _storage.saveRefreshToken(authResponse.refreshToken!);
    }
    await _storage.saveTokenExpiry(authResponse.expiresAt);
    await _storage.saveUser(authResponse.user);
  }

  String _mapError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please check your connection and try again.';
    }

    const fallbackMessage =
        'Unable to complete your request right now. Please try again later.';

    final response = error.response;
    if (response != null) {
      final extracted = _extractErrorMessage(response.data);
      if (extracted != null && extracted.trim().isNotEmpty) {
        return extracted.trim();
      }

      switch (response.statusCode) {
        case 401:
          return 'Invalid credentials, please try again.';
        case 422:
          return 'Provided data is invalid. Please review your inputs.';
        default:
          if ((response.statusMessage ?? '').isNotEmpty) {
            return '${response.statusMessage}. Please try again later.';
          }
          return fallbackMessage;
      }
    }

    return fallbackMessage;
  }

  String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      for (final key in const ['message', 'error', 'detail', 'description']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
      final errors = data['errors'];
      if (errors is Map) {
        final parts = <String>[];
        for (final value in errors.values) {
          if (value is String) {
            parts.add(value);
          } else if (value is Iterable) {
            parts.addAll(value.whereType<String>());
          }
        }
        if (parts.isNotEmpty) {
          return parts.join('\n');
        }
      } else if (errors is Iterable) {
        final parts = errors.whereType<String>().toList();
        if (parts.isNotEmpty) {
          return parts.join('\n');
        }
      }
    }
    if (data is Iterable) {
      final parts = data.whereType<String>().toList();
      if (parts.isNotEmpty) {
        return parts.join('\n');
      }
    }
    return null;
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
