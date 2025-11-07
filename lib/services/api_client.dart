import 'package:dio/dio.dart';

import '../config/env.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = _createDio();

  static Dio _createDio() {
    final baseUrl = AppEnv.resolvedApiBaseUrl();
    // ignore: avoid_print
    print('[HTTP] Dio baseUrl: $baseUrl');
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Content-Type': 'application/json'},
        // Accept 4xx so we can map error bodies; let code handle throws.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.next(options),
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) => handler.next(error),
      ),
    );

    return dio;
  }

  static Dio get instance => _dio;
}
