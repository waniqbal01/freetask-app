import 'package:dio/dio.dart';

import '../auth/role_permission.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../models/user_roles.dart';
import 'session_api_client.dart';
import 'storage_service.dart';

class AuthService {
  AuthService(this._apiClient, this._storage);

  final SessionApiClient _apiClient;
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
        options: _apiClient.guard(requiresAuth: false),
      );
      final data = _unwrapData(response.data);
      final authResponse = AuthResponse.fromJson(data);
      return _persistAndHydrateSession(authResponse);
    } on DioException catch (error) {
      _logDioException(error);
      throw AuthException(_mapError(error));
    }
  }

  Future<AuthResponse> signup({
    required String name,
    required String email,
    required String password,
    String role = kDefaultUserRoleName,
  }) async {
    try {
      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/auth/signup',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        },
        options: _apiClient.guard(requiresAuth: false),
      );
      final data = _unwrapData(response.data);
      final authResponse = AuthResponse.fromJson(data);
      return _persistAndHydrateSession(authResponse);
    } on DioException catch (error) {
      _logDioException(error);
      throw AuthException(_mapError(error));
    }
  }

  Future<User> fetchMe() async {
    try {
      final response = await _apiClient.client.get<Map<String, dynamic>>(
        '/users/me',
        options: _apiClient.guard(permission: RolePermission.viewDashboard),
      );
      final data = _unwrapData(response.data);
      final userMap = data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : data;
      final user = User.fromJson(userMap);
      await _storage.saveUser(user);
      return user;
    } on DioException catch (error) {
      _logDioException(error);
      throw AuthException(_mapError(error));
    }
  }

  Future<void> logout() async {
    final refreshToken = _storage.refreshToken;
    try {
      await _apiClient.client.post<void>(
        '/auth/logout',
        data: {
          if (refreshToken != null && refreshToken.isNotEmpty)
            'refreshToken': refreshToken,
        },
        options: _apiClient.guard(permission: RolePermission.viewDashboard),
      );
    } on DioException catch (error) {
      _logDioException(error);
      if (error.response?.statusCode != 401) {
        rethrow;
      }
    } finally {
      await _storage.clearAll();
    }
  }

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
        options: _apiClient.guard(requiresAuth: false),
      );
      final data = _unwrapData(response.data);
      final newToken =
          data['accessToken'] as String? ?? data['token'] as String? ?? '';
      if (newToken.isEmpty) {
        await _storage.clearAll();
        throw AuthException('Unable to refresh session. Please sign in again.');
      }

      final newRefreshToken = data['refreshToken'] as String? ??
          data['refresh_token'] as String? ??
          data['refresh'] as String?;
      final expiresRaw =
          data['expiresAt'] ?? data['expires_in'] ?? data['expiresIn'];
      final expiresAt = AuthResponse.parseExpiry(expiresRaw);

      await _storage.saveToken(newToken);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.saveRefreshToken(newRefreshToken);
      } else {
        await _storage.clearRefreshToken();
      }
      await _storage.saveTokenExpiry(expiresAt);
      return newToken;
    } on DioException catch (error) {
      _logDioException(error);
      await _storage.clearAll();
      throw AuthException(_mapError(error));
    }
  }

  Future<AuthResponse> _persistAndHydrateSession(
    AuthResponse authResponse,
  ) async {
    await _storage.saveToken(authResponse.token);
    final refreshToken = authResponse.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.saveRefreshToken(refreshToken);
    } else {
      await _storage.clearRefreshToken();
    }
    await _storage.saveTokenExpiry(authResponse.expiresAt);

    try {
      var user = authResponse.user;
      if (user.id.isEmpty || user.email.isEmpty) {
        if (user.role.isNotEmpty) {
          await _storage.saveRole(ensureUserRoleName(user.role));
        }
        user = await fetchMe();
      }
      await _storage.saveUser(user);
      return AuthResponse(
        token: authResponse.token,
        refreshToken: refreshToken,
        expiresAt: authResponse.expiresAt,
        user: user,
      );
    } catch (error) {
      await _storage.clearAll();
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      await _apiClient.client.post<void>(
        '/auth/forgot-password',
        data: {'email': email},
        options: _apiClient.guard(requiresAuth: false),
      );
    } on DioException catch (error) {
      _logDioException(error);
      throw AuthException(_mapError(error));
    }
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String token,
    required String password,
  }) async {
    try {
      await _apiClient.client.post<void>(
        '/auth/reset-password',
        data: {
          'email': email,
          'token': token,
          'password': password,
        },
        options: _apiClient.guard(requiresAuth: false),
      );
    } on DioException catch (error) {
      _logDioException(error);
      throw AuthException(_mapError(error));
    }
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      await _apiClient.client.post<void>(
        '/auth/verify-email',
        data: {
          'email': email,
          'code': code,
        },
        options: _apiClient.guard(requiresAuth: false),
      );
    } on DioException catch (error) {
      _logDioException(error);
      throw AuthException(_mapError(error));
    }
  }

  void _logDioException(DioException error) {
    // ignore: avoid_print
    print(
      '[DIO][TYPE]=${error.type} | [MSG]=${error.message} | [CODE]=${error.response?.statusCode}',
    );
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
      final nestedError = data['error'];
      if (nestedError is Map<String, dynamic>) {
        final message = nestedError['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
        final details = nestedError['details'];
        if (details is String && details.trim().isNotEmpty) {
          return details;
        }
      }
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

  Map<String, dynamic> _unwrapData(Map<String, dynamic>? data) {
    if (data == null) {
      return <String, dynamic>{};
    }
    if (data['data'] is Map<String, dynamic>) {
      final inner = data['data'] as Map<String, dynamic>;
      if (inner['user'] is Map<String, dynamic> ||
          inner['profile'] is Map<String, dynamic> ||
          inner['accessToken'] != null ||
          inner['token'] != null) {
        return inner;
      }
    }
    if (data['user'] is Map<String, dynamic>) {
      return data;
    }
    if (data['profile'] is Map<String, dynamic>) {
      return data;
    }
    if (data['accessToken'] != null || data['token'] != null) {
      return data;
    }
    return data;
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}
