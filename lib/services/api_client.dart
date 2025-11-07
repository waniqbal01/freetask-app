import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

String _resolveBaseUrl() {
  const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (kIsWeb) {
    if (envUrl.isNotEmpty) return envUrl;
    // default: same-origin + /api (guna dev proxy untuk elak CORS)
    final origin = Uri.base.origin; // contoh: http://localhost:5555
    return '$origin/api';
  } else {
    if (envUrl.isNotEmpty) return envUrl;
    // Android emulator -> host machine
    return 'http://10.0.2.2:4000';
  }
}

class ApiClient {
  static final ApiClient _i = ApiClient._internal();
  factory ApiClient() => _i;
  late final Dio dio;

  ApiClient._internal() {
    final baseUrl = _resolveBaseUrl();
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // print('[http] ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (res, handler) => handler.next(res),
      onError: (e, handler) {
        // print('[http][error] type=${e.type} msg=${e.message}');
        handler.next(e);
      },
    ));
  }
}
