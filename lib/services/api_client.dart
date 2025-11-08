import 'package:dio/dio.dart';

import '../config/env.dart';

class ApiClient {
  factory ApiClient() => _instance;

  ApiClient._internal() {
    final resolved = AppEnv.resolvedApiBaseUrl();
    final baseUrl = resolved.isNotEmpty ? resolved : Env.apiBaseUrl;
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {
          'Content-Type': 'application/json',
        },
        validateStatus: (code) => code != null && code >= 200 && code < 500,
      ),
    );
  }

  static final ApiClient _instance = ApiClient._internal();

  late final Dio _dio;

  Dio get client => _dio;

  static Dio get instance => ApiClient().client;
}
