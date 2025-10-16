import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import '../utils/role_permissions.dart';
import 'role_guard.dart';
import 'storage_service.dart';

class ApiClient {
  ApiClient(Dio dio, this._storage, this._roleGuard)
      : _dio = dio
          ..options = BaseOptions(
            baseUrl: Env.apiBase,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: const {'Content-Type': 'application/json'},
          ) {
    _dio.interceptors.clear();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.token;
          final requiresAuth =
              (options.extra['requiresAuth'] as bool?) ?? true;
          if (requiresAuth && token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          final role = _roleGuard.currentRole ?? _storage.role;
          if (role != null && role.isNotEmpty) {
            options.headers['X-User-Role'] = role;
          }

          final allowedRoles = (options.extra['allowedRoles'] as List?)
                  ?.whereType<String>()
                  .toSet() ??
              const <String>{};
          if (allowedRoles.isNotEmpty) {
            try {
              _roleGuard.ensureRoleIn(
                allowedRoles,
                actionDescription:
                    options.extra['requiredPermission']?.toString() ??
                        'perform this action',
              );
            } on RoleUnauthorizedException catch (error) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  error: error,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 403,
                    data: {
                      'message': error.message,
                      'requiredRoles': allowedRoles.toList(),
                    },
                  ),
                ),
              );
            }
          }

          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode != 401 ||
              error.requestOptions.extra['skipAuth'] == true ||
              _refreshCallback == null) {
            return handler.next(error);
          }

          try {
            await _refreshToken();
          } catch (_) {
            await _storage.clearAll();
            return handler.next(error);
          }

          final refreshedToken = _storage.token;
          if (refreshedToken == null || refreshedToken.isEmpty) {
            await _storage.clearAll();
            return handler.next(error);
          }

          final requestOptions = error.requestOptions;
          requestOptions.headers['Authorization'] = 'Bearer $refreshedToken';
          requestOptions.extra = Map<String, dynamic>.from(requestOptions.extra)
            ..['skipAuth'] = true;

          try {
            final response = await _dio.fetch<dynamic>(requestOptions);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final StorageService _storage;
  final RoleGuard _roleGuard;
  Future<String> Function()? _refreshCallback;
  Completer<void>? _refreshCompleter;

  Dio get client => _dio;

  void registerRefreshTokenCallback(Future<String> Function() callback) {
    _refreshCallback = callback;
  }

  Options guard({
    RolePermission? permission,
    bool requiresAuth = true,
    Set<String>? allowedRoles,
  }) {
    final extra = <String, dynamic>{'requiresAuth': requiresAuth};
    if (permission != null) {
      final config = RolePermissions.config(permission);
      extra['requiredPermission'] = config.description;
      extra['allowedRoles'] = config.allowedRoles.toList();
      extra['requiresAuth'] = config.requiresAuth;
    }
    if (allowedRoles != null) {
      final combined = <String>{
        ...((extra['allowedRoles'] as List?)?.whereType<String>() ?? const []),
        ...allowedRoles,
      };
      extra['allowedRoles'] = combined.toList();
    }
    return Options(extra: extra);
  }

  Future<void> _refreshToken() async {
    if (_refreshCallback == null) return;
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<void>();
    try {
      await _refreshCallback!.call();
      _refreshCompleter!.complete();
    } catch (error) {
      if (!(_refreshCompleter?.isCompleted ?? true)) {
        _refreshCompleter!.completeError(error);
      }
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }
}
