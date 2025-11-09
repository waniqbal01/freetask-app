import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/role_permission.dart';
import '../utils/role_permissions.dart';
import 'api_client.dart';
import 'role_guard.dart';
import 'storage_service.dart';

class SessionApiClient {
  SessionApiClient({
    RoleGuard? roleGuard,
    required StorageService storage,
    Dio? dio,
  })  : _roleGuard = roleGuard,
        _storage = storage,
        _apiClient = ApiClient(storage: storage) {
    _dio = dio ?? _apiClient.dio;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final requiresAuth = (options.extra['requiresAuth'] as bool?) ?? true;
          if (requiresAuth && _roleGuard != null) {
            final allowedRoles = (options.extra['allowedRoles'] as List?)
                    ?.whereType<String>()
                    .toSet() ??
                const <String>{};
            if (allowedRoles.isNotEmpty) {
              try {
                _roleGuard!.ensureRoleIn(
                  allowedRoles,
                  actionDescription:
                      options.extra['requiredPermission']?.toString(),
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
                        'requiredRoles': error.requiredRoles?.toList(),
                      },
                    ),
                  ),
                );
              }
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode ?? 0;
          final requiresAuth =
              (error.requestOptions.extra['requiresAuth'] as bool?) ?? true;
          if (statusCode == 401 && requiresAuth) {
            final retryResponse = await _attemptTokenRefresh(error.requestOptions);
            if (retryResponse != null) {
              return handler.resolve(retryResponse);
            }
            await _handleUnauthorized();
          }
          handler.next(error);
        },
      ),
    );
  }

  final RoleGuard? _roleGuard;
  final StorageService _storage;
  final ApiClient _apiClient;
  late final Dio _dio;

  Future<String> Function()? _refreshCallback;
  Completer<void>? _refreshCompleter;
  final _logoutController = StreamController<void>.broadcast();

  Dio get client => _dio;
  Stream<void> get logoutStream => _logoutController.stream;

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
    if (allowedRoles != null && allowedRoles.isNotEmpty) {
      final existing =
          (extra['allowedRoles'] as List?)?.whereType<String>().toSet() ??
              <String>{};
      extra['allowedRoles'] = {...existing, ...allowedRoles}.toList();
    }
    return Options(extra: extra);
  }

  Future<Response<dynamic>?> _attemptTokenRefresh(RequestOptions options) async {
    if (options.extra['__retried__'] == true) {
      return null;
    }

    final refreshed = await _refreshSession();
    if (!refreshed) {
      return null;
    }

    final token = _storage.token;
    if (token == null || token.isEmpty) {
      return null;
    }

    options.headers['Authorization'] = 'Bearer $token';
    options.extra = Map<String, dynamic>.from(options.extra)
      ..['__retried__'] = true;

    try {
      final response = await _dio.fetch<dynamic>(options);
      return response;
    } on DioException {
      return null;
    }
  }

  Future<bool> _refreshSession() async {
    if (_refreshCallback != null) {
      if (_refreshCompleter != null) {
        await _refreshCompleter!.future;
        return true;
      }
      _refreshCompleter = Completer<void>();
      try {
        final token = await _refreshCallback!.call();
        return token.isNotEmpty;
      } catch (_) {
        return false;
      } finally {
        _refreshCompleter?.complete();
        _refreshCompleter = null;
      }
    }

    return false;
  }

  Future<void> _handleUnauthorized() async {
    await _storage.clearAll();
    if (!_logoutController.isClosed) {
      _logoutController.add(null);
    }
  }
}
