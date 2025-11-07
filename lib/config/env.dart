import 'package:flutter/foundation.dart' show kIsWeb;

class AppEnv {
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const String appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'Freetask');
  static const bool enableSentry =
      bool.fromEnvironment('ENABLE_SENTRY', defaultValue: false);

  // Use runtime values if provided, else sensible defaults per platform
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();

  static String resolvedApiBaseUrl() {
    // If provided by --dart-define, use it.
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl;

    // Defaults when not provided:
    // Web dev uses host machine localhost; Android emulator uses 10.0.2.2
    if (kIsWeb) return 'http://localhost:4000';
    return 'http://10.0.2.2:4000';
  }
}
