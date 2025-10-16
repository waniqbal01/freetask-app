import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import '../utils/role_permissions.dart';
import 'role_guard.dart';
import 'storage_service.dart';

class ApiClient {
  ApiClient(this._dio, this._storage, this._roleGuard) {
    _dio
      ..options = BaseOptions(
        baseUrl: Env.apiBase,
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 25),
        headers: {'Content-Type': 'application/json'},
      )
      ..interceptors.add(
        QueuedInterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.extra['skipAuth'] == true) {
              return handler.next(options);
            }
            final token = _storage.token;
            final requiresAuth =
                (options.extra['requiresAuth'] as bool?) ?? true;
            if (requiresAuth) {
              if (token == null || token.isEmpty) {
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.badResponse,
                    response: Response<dynamic>(
                      requestOptions: options,
                      statusCode: 401,
                      data: {'message': 'Authentication required.'},
                    ),
                  ),
                );
              }
              options.headers['Authorization'] = 'Bearer $token';
            } else if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }

            final role = _roleGuard.currentRole;
            if (role != null && role.isNotEmpty) {
              options.headers['X-User-Role'] = role;
            }

            final allowedRoles =
                (options.extra['allowedRoles'] as List<dynamic>?)
                    ?.whereType<String>()
                    .toSet();
            if (allowedRoles != null && allowedRoles.isNotEmpty) {
              try {
                _roleGuard.ensureRoleIn(
                  allowedRoles,
                  actionDescription:
                      'You do not have permission to access this resource.',
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
            final response = error.response;
            if (response?.statusCode != 401 ||
                error.requestOptions.extra['skipAuth'] == true ||
                error.requestOptions.extra['retried'] == true ||
                _refreshTokenCallback == null) {
              return handler.next(error);
            }

            try {
              await _refreshToken();
            } on Exception {
              await _storage.clearAll();
              return handler.next(error);
            }

            final refreshedToken = _storage.token;
            if (refreshedToken == null || refreshedToken.isEmpty) {
              await _storage.clearAll();
              return handler.next(error);
            }

            final requestOptions = error.requestOptions;
            requestOptions.headers
                .addAll(<String, dynamic>{'Authorization': 'Bearer $refreshedToken'});
            requestOptions.extra = Map<String, dynamic>.from(requestOptions.extra)
              ..['retried'] = true;

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
  Future<String> Function()? _refreshTokenCallback;
  Completer<void>? _refreshCompleter;

  void registerRefreshTokenCallback(Future<String> Function() callback) {
    _refreshTokenCallback = callback;
  }

  Dio get client => _dio;

  Options guard({
    RolePermission? permission,
    bool? requiresAuth,
    Set<String>? allowedRoles,
  }) {
    final extra = <String, dynamic>{};
    if (permission != null) {
      final config = RolePermissions.config(permission);
      extra['requiredPermission'] = permission.name;
      extra['allowedRoles'] = config.allowedRoles.toList();
      extra['requiresAuth'] = config.requiresAuth;
    }
    if (requiresAuth != null) {
      extra['requiresAuth'] = requiresAuth;
    }
    if (allowedRoles != null) {
      final combined = <String>{
        ...((extra['allowedRoles'] as List<dynamic>?)
                ?.whereType<String>()
                .toSet() ??
            const <String>{}),
        ...allowedRoles,
      };
      extra['allowedRoles'] = combined.toList();
    }
    return Options(extra: extra);
  }

  Future<void> _refreshToken() async {
    if (_refreshTokenCallback == null) return;

    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<void>();
    try {
      await _refreshTokenCallback!.call();
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
