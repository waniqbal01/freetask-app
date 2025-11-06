import 'package:flutter/foundation.dart';

class AppEnv {
  static const _configuredApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:4000');

  static String get apiBaseUrl {
    if (kIsWeb && Uri.base.scheme == 'https') {
      final parsed = Uri.tryParse(_configuredApiBaseUrl);
      if (parsed != null && parsed.scheme == 'http') {
        return parsed.replace(scheme: 'https').toString();
      }
    }
    return _configuredApiBaseUrl;
  }

  static const apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:4000');
  static const sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'Freetask');
  static const enableSentry =
      bool.fromEnvironment('ENABLE_SENTRY', defaultValue: false);
}
