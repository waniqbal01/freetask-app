import 'package:dio/dio.dart';
import '../config/routes.dart';
import 'storage_service.dart';

class ApiClient {
  final Dio dio;
  final StorageService storage;

  ApiClient({required this.storage})
      : dio = Dio(BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          // 4xx dianggap error supaya aliran error konsisten
          validateStatus: (code) => code != null && code >= 200 && code < 400,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        )) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final requiresAuth = (options.extra['requiresAuth'] as bool?) ?? true;
          if (!requiresAuth) {
            options.headers.remove('Authorization');
            return handler.next(options);
          }

          final token = storage.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onError: (e, handler) {
          handler.next(e);
        },
      ),
    );
  }
}
