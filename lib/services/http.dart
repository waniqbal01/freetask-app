import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../config/env.dart';

Dio createDio() {
  final baseUrl = Env.apiBaseUrl;
  developer.log('Configuring Dio baseUrl: $baseUrl', name: 'http');

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      error: true,
    ),
  );

  return dio;
}
