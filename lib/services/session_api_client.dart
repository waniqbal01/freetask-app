import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/role_permission.dart';
import '../core/app_logger.dart';
import '../utils/role_permissions.dart';
import 'api_client.dart';
import 'monitoring_service.dart';
import 'role_guard.dart';
import 'storage_service.dart';

class SessionApiClient {
  SessionApiClient({
    Dio? dio,
    required StorageService storage,
    required RoleGuard roleGuard,
  })  : _dio = dio ?? ApiClient().dio,
        _storage = storage,
        _roleGuard = roleGuard {
    final existingHeaders = Map<String, dynamic>.from(
      _dio.options.headers ?? const <String, dynamic>{},
    );
    existingHeaders['Content-Type'] =
        existingHeaders['Content-Type'] ?? 'application/json';

    final options = _dio.options;
    _dio.options = options.copyWith(
      connectTimeout: options.connectTimeout ?? const Duration(seconds: 10),
      receiveTimeout: options.receiveTimeout ?? const Duration(seconds: 20),
      sendTimeout: options.sendTimeout ?? const Duration(seconds: 20),
      headers: existingHeaders,
    );

    _interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLogger.d('→ ${options.method} ${options.uri}');
        final token = _storage.token;
        final requiresAuth = (options.extra['requiresAuth'] as bool?) ?? true;
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
      onResponse: (response, handler) {
        AppLogger.d(
            '← ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');
        final requestId = response.headers.value('x-request-id');
        MonitoringService.updateRequestContext(requestId);
        return handler.next(response);
      },
      onError: (error, handler) async {
        AppLogger.e(
          '✖ ${error.requestOptions.method} ${error.requestOptions.uri}: ${error.message}',
          error,
          error.stackTrace,
        );
        final options = error.requestOptions;
        if ((error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout) &&
            ((options.extra['__retry__'] as int?) ?? 0) < 2) {
          final retries = ((options.extra['__retry__'] as int?) ?? 0) + 1;
          final extra = Map<String, dynamic>.from(options.extra);
          extra['__retry__'] = retries;
          options.extra = extra;
          AppLogger.w(
              'Retrying ${options.method} ${options.uri} (attempt $retries) due to ${error.type}');
          try {
            final response = await _dio.fetch<dynamic>(options);
            return handler.resolve(response);
          } on DioException catch (retryError) {
            return handler.next(retryError);
          }
        }
        final response = error.response;
        final statusCode = response?.statusCode;
        final headers = response?.headers;
        final requestId = headers?.value('x-request-id');
        MonitoringService.updateRequestContext(requestId);
        if ((statusCode ?? 0) >= 500) {
          await MonitoringService.recordError(
            error,
            error.stackTrace,
          );
        }
        final isSkipAuth = error.requestOptions.extra['skipAuth'] == true;
        if (statusCode != 401 || isSkipAuth) {
          if (statusCode == 401 && !isSkipAuth) {
            await _handleUnauthorized();
          }
          return handler.next(error);
        }

        if (_refreshCallback == null) {
          await _handleUnauthorized();
          return handler.next(error);
        }

        try {
          await _refreshToken();
        } catch (_) {
          await _handleUnauthorized();
          return handler.next(error);
        }

        final refreshedToken = _storage.token;
        if (refreshedToken == null || refreshedToken.isEmpty) {
          await _handleUnauthorized();
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
    );

    _dio.interceptors.add(_interceptor);
  }

  final Dio _dio;
  final StorageService _storage;
  final RoleGuard _roleGuard;
  late final Interceptor _interceptor;
  Future<String> Function()? _refreshCallback;
  Completer<void>? _refreshCompleter;
  final _unauthorizedController = StreamController<void>.broadcast();

  Dio get client => _dio;

  Stream<void> get logoutStream => _unauthorizedController.stream;

  void setRefreshCallback(Future<String> Function() callback) {
    _refreshCallback = callback;
  }

  @Deprecated('Use setRefreshCallback instead')
  void registerRefreshTokenCallback(Future<String> Function() callback) {
    setRefreshCallback(callback);
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
      final completer = _refreshCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error);
      }
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _handleUnauthorized() async {
    await _storage.clearAll();
    if (!_unauthorizedController.isClosed) {
      _unauthorizedController.add(null);
    }
  }

  Future<void> close() async {
    await _unauthorizedController.close();
    _dio.interceptors.remove(_interceptor);
  }
}
