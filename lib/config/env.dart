import 'package:flutter/foundation.dart' show kIsWeb;

String _sanitizeBaseUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) {
    return trimmed;
  }

  final normalizedPath = parsed.path.replaceAll(RegExp(r'/+$'), '');
  final normalized = parsed.replace(path: normalizedPath);
  return normalized.toString();
}

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
    final runtimeUrl = _runtimeOverride();
    if (runtimeUrl != null && runtimeUrl.isNotEmpty) {
      return _translateLocalhost(runtimeUrl);
    }

    final envUrl = _sanitizeBaseUrl(apiBaseUrl);
    if (envUrl.isEmpty) {
      return _defaultForPlatform();
    }

    return _translateLocalhost(envUrl);
  }

  static String _defaultForPlatform() {
    if (kIsWeb) {
      final baseOrigin = Uri.base;
      final origin = baseOrigin.hasAuthority ? baseOrigin.origin : '';
      if (origin.isNotEmpty &&
          baseOrigin.host.isNotEmpty &&
          baseOrigin.host != 'localhost' &&
          baseOrigin.host != '127.0.0.1') {
        return origin;
      }
      return _defaultLocalBaseUrl;
    }

    return 'http://10.0.2.2:4000';
  }

  static String _translateLocalhost(String url) {
    if (kIsWeb) {
      return url;
    }

    final parsed = Uri.tryParse(url);
    if (parsed != null &&
        (parsed.host == 'localhost' || parsed.host == '127.0.0.1')) {
      final translated = parsed.replace(host: '10.0.2.2');
      return translated.toString();
    }
    return url;
  }

  static String? _runtimeOverride() {
    if (!kIsWeb) {
      return null;
    }

    final uri = Uri.base;
    final fragmentQuery = () {
      final fragment = uri.fragment;
      final queryIndex = fragment.indexOf('?');
      if (queryIndex == -1 || queryIndex >= fragment.length - 1) {
        return const <String, String>{};
      }
      final queryString = fragment.substring(queryIndex + 1);
      return Uri(query: queryString).queryParameters;
    }();

    final candidates = <String?>[
      uri.queryParameters['apiBaseUrl'] ?? fragmentQuery['apiBaseUrl'],
      uri.queryParameters['api_base_url'] ?? fragmentQuery['api_base_url'],
      uri.queryParameters['api'] ?? fragmentQuery['api'],
    ];

    for (final candidate in candidates) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return _sanitizeBaseUrl(candidate);
      }
    }

    return null;
  }
}
