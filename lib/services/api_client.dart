import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import 'storage_service.dart';

class ApiClient {
  ApiClient(this._dio, this._storage) {
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
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
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
  Future<String> Function()? _refreshTokenCallback;
  Completer<void>? _refreshCompleter;

  void registerRefreshTokenCallback(Future<String> Function() callback) {
    _refreshTokenCallback = callback;
  }

  Dio get client => _dio;

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
