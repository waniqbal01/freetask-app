import 'package:dio/dio.dart';

Dio createDio() {
  final dio = Dio();

  dio.options = dio.options.copyWith(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15),
    headers: const {'Content-Type': 'application/json'},
  );

  dio.interceptors.add(LogInterceptor(
    request: true,
    requestBody: true,
    responseBody: true,
    error: true,
  ));

  return dio;
}
