import 'package:dio/dio.dart';
import '../config/routes.dart';
import '../auth/firebase_auth_service.dart';

class ApiClient {
  final Dio dio;
  final FirebaseAuthService auth;

  ApiClient({required this.auth})
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

          final token = await auth.getIdToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onError: (e, handler) {
          // Log ringkas; anda boleh tambah mapping mesej di sini
          // Jika 401 disebabkan token tamat, Firebase akan keluarkan token baru automatik bila next getIdToken(forceRefresh: true)
          handler.next(e);
        },
      ),
    );
  }
}
