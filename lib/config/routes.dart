import 'package:flutter/material.dart';
import 'package:freetask_app/features/auth/presentation/login_page.dart';
import 'package:freetask_app/features/auth/presentation/register_page.dart';
import 'package:freetask_app/features/home/presentation/home_page.dart';

class ApiConfig {
  // API asas anda – ubah dengan --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:4000',
  );
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
