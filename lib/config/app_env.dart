import 'package:flutter/foundation.dart';

class AppEnv {
  static final String apiBaseUrl = _resolveApiBaseUrl();
  static const sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'Freetask');
  static const enableSentry =
      bool.fromEnvironment('ENABLE_SENTRY', defaultValue: false);

  static String _resolveApiBaseUrl() {
    const globalOverride = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );
    if (globalOverride.isNotEmpty) {
      return globalOverride;
    }

    if (kIsWeb) {
      const webOverride = String.fromEnvironment(
        'API_BASE_URL_WEB',
        defaultValue: '',
      );
      if (webOverride.isNotEmpty) {
        return webOverride;
      }

      final browserOrigin = Uri.base;
      final host = browserOrigin.host.isEmpty ? 'localhost' : browserOrigin.host;
      final scheme = browserOrigin.scheme.isEmpty ? 'http' : browserOrigin.scheme;

      if (host == 'localhost' || host == '127.0.0.1') {
        return '$scheme://$host:4000';
      }

      return '$scheme://$host';
    }

    const mobileOverride = String.fromEnvironment(
      'API_BASE_URL_MOBILE',
      defaultValue: '',
    );
    if (mobileOverride.isNotEmpty) {
      return mobileOverride;
    }

    return 'http://10.0.2.2:3000';
  }
}
