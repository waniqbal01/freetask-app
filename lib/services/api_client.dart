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
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final token = _storage.token;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            return handler.next(options);
          },
          onError: (error, handler) async {
            if (error.response?.statusCode == 401) {
              await _storage.clearAll();
            }
            return handler.next(error);
          },
        ),
      );
  }

  final Dio _dio;
  final StorageService _storage;

  Dio get client => _dio;
}
