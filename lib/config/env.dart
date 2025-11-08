import 'package:flutter/foundation.dart' show kIsWeb;

class AppEnv {
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const String appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'Freetask');
  static const bool enableSentry =
      bool.fromEnvironment('ENABLE_SENTRY', defaultValue: false);

  static const String _defaultLocalBaseUrl = 'http://localhost:4000';

  // Use runtime values if provided, else sensible defaults per platform
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultLocalBaseUrl,
  );

  static String resolvedApiBaseUrl() {
    final envUrl = apiBaseUrl.trim();
    if (envUrl.isEmpty) {
      return kIsWeb ? _defaultLocalBaseUrl : 'http://10.0.2.2:4000';
    }

    if (!kIsWeb) {
      final parsed = Uri.tryParse(envUrl);
      if (parsed != null &&
          (parsed.host == 'localhost' || parsed.host == '127.0.0.1')) {
        final translated = parsed.replace(host: '10.0.2.2');
        return translated.toString();
      }
    }

    return envUrl;
  }
}
