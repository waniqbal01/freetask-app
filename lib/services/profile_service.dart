import 'dart:io';

import 'package:dio/dio.dart';

import '../auth/role_permission.dart';
import '../models/user.dart';
import '../utils/logger.dart';
import 'session_api_client.dart';
import 'storage_service.dart';

class ProfileService {
  ProfileService(this._apiClient, this._storage);

  final SessionApiClient _apiClient;
  final StorageService _storage;

  Future<User> fetchCurrentUser() async {
    try {
      final response = await _apiClient.client.get<Map<String, dynamic>>(
        '/users/me',
        options: _apiClient.guard(permission: RolePermission.viewDashboard),
      );
      final data = response.data ?? <String, dynamic>{};
      final user = User.fromJson(data);
      await _storage.saveUser(user);
      return user;
    } on DioException catch (error, stackTrace) {
      AppLogger.e('Failed to fetch current user', error: error, stackTrace: stackTrace);
      throw ProfileException(_mapError(error));
    }
  }

  Future<User> updateProfile({
    required String name,
    required String email,
    String? bio,
    String? location,
    String? phoneNumber,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'email': email,
        'bio': bio,
        'location': location,
        'phoneNumber': phoneNumber,
      }..removeWhere((key, value) => value == null);

      final response = await _apiClient.client.put<Map<String, dynamic>>(
        '/users/update',
        data: payload,
        options: _apiClient.guard(permission: RolePermission.viewDashboard),
      );
      final data = response.data ?? <String, dynamic>{};
      final user = User.fromJson(data);
      await _storage.saveUser(user);
      return user;
    } on DioException catch (error, stackTrace) {
      AppLogger.e('Failed to update profile', error: error, stackTrace: stackTrace);
      throw ProfileException(_mapError(error));
    }
  }

  Future<String?> uploadAvatar(File file) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _apiClient.client.post<Map<String, dynamic>>(
        '/users/upload-avatar',
        data: formData,
        options: _apiClient
            .guard(permission: RolePermission.viewDashboard)
            .copyWith(contentType: 'multipart/form-data'),
      );
      final data = response.data ?? <String, dynamic>{};
      final url = data['avatarUrl'] ?? data['avatar_url'] ?? data['url'];
      if (url is String && url.isNotEmpty) {
        final cached = _storage.getUser();
        if (cached != null) {
          final updated = cached.copyWith(avatarUrl: url);
          await _storage.saveUser(updated);
        }
      }
      return url is String ? url : null;
    } on DioException catch (error, stackTrace) {
      AppLogger.e('Failed to upload avatar', error: error, stackTrace: stackTrace);
      throw ProfileException(_mapError(error));
    }
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
          return 'Session expired. Please log in again.';
        case 403:
          return 'You do not have permission to perform this action.';
        case 404:
          return 'Requested resource not found.';
        case 422:
          return 'Provided information is invalid. Please review your inputs.';
        default:
          return 'Unexpected server error (${response.statusCode}).';
      }
    }

    return 'Something went wrong. Please try again later.';
  }
}

class ProfileException implements Exception {
  ProfileException(this.message);

  final String message;

  @override
  String toString() => 'ProfileException: $message';
}
