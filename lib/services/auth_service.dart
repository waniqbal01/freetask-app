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
      );
      final data = response.data ?? <String, dynamic>{};
      final authResponse = AuthResponse.fromJson(data);
      await _persistSession(authResponse);
      return authResponse;
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
      );
      final data = response.data ?? <String, dynamic>{};
      final authResponse = AuthResponse.fromJson(data);
      await _persistSession(authResponse);
      return authResponse;
    } on DioException catch (error) {
      throw AuthException(_mapError(error));
    }
  }

  Future<User> fetchMe() async {
    try {
      final response = await _apiClient.client.get<Map<String, dynamic>>(
        '/auth/me',
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

  Future<void> _persistSession(AuthResponse authResponse) async {
    await _storage.saveToken(authResponse.token);
    await _storage.saveUser(authResponse.user);
  }

  String _mapError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please check your connection and try again.';
    }

    final response = error.response;
    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['message'] is String) {
          return data['message'] as String;
        }
        if (data['error'] is String) {
          return data['error'] as String;
        }
      }
      switch (response.statusCode) {
        case 401:
          return 'Invalid credentials, please try again.';
        case 422:
          return 'Provided data is invalid. Please review your inputs.';
        default:
          return 'Unexpected server error (${response.statusCode}).';
      }
    }

    return 'Something went wrong. Please try again later.';
  }
}

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: ' + message;
}
