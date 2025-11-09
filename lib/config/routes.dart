import 'package:flutter/material.dart';
import 'package:freetask_app/features/auth/presentation/login_page.dart';
import 'package:freetask_app/features/auth/presentation/register_page.dart';
import 'package:freetask_app/features/home/presentation/home_page.dart';

class ApiConfig {
  // API asas anda – ubah dengan --dart-define=API_BASE_URL=...
  static final String baseUrl = _normaliseBaseUrl(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:4000',
    ),
  );

  static String _normaliseBaseUrl(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return 'http://127.0.0.1:4000';
    }

    try {
      final uri = Uri.parse(value);
      final host = uri.host;
      final isLocalhost = host == 'localhost' || host == '127.0.0.1' || host == '[::1]';

      if (isLocalhost && uri.scheme == 'https') {
        return uri.replace(scheme: 'http').toString();
      }

      return uri.toString();
    } catch (_) {
      return value;
    }
  }
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case LoginPage.route:
      return MaterialPageRoute(builder: (_) => const LoginPage());
    case RegisterPage.route:
      return MaterialPageRoute(builder: (_) => const RegisterPage());
    case HomePage.route:
      return MaterialPageRoute(builder: (_) => const HomePage());
    default:
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('404')),
          body: const Center(child: Text('Route tidak dijumpai')),
        ),
      );
  }
}
