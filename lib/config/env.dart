import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

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

  static const String _defaultLocalBaseUrl = 'http://127.0.0.1:4000';

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
      final hostedBase = _resolveHostedDevBase(baseOrigin);
      if (hostedBase != null) {
        return hostedBase;
      }
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
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      return url;
    }

    if (kIsWeb) {
      if (parsed.host == 'localhost' || parsed.host == '::1') {
        return parsed.replace(host: '127.0.0.1').toString();
      }
      return url;
    }

    if (parsed.host == 'localhost' || parsed.host == '127.0.0.1' ||
        parsed.host == '::1') {
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

  static String? _resolveHostedDevBase(Uri uri) {
    final host = uri.host;
    if (host.isEmpty) {
      return null;
    }

    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;

    final codespaceMatch = RegExp(
      r'^(?<prefix>.+)-(?<port>\d+)(?<suffix>\.(?:app\.github\.dev|githubpreview\.dev))$',
    ).firstMatch(host);
    if (codespaceMatch != null) {
      final prefix = codespaceMatch.namedGroup('prefix')!;
      final suffix = codespaceMatch.namedGroup('suffix')!;
      final newHost = '$prefix-4000$suffix';
      return Uri(scheme: scheme, host: newHost).toString();
    }

    final gitpodMatch =
        RegExp(r'^(?<port>\d+)-(?<rest>.+\.gitpod\.io)$').firstMatch(host);
    if (gitpodMatch != null) {
      final rest = gitpodMatch.namedGroup('rest')!;
      final newHost = '4000-$rest';
      return Uri(scheme: scheme, host: newHost).toString();
    }

    return null;
  }

  @visibleForTesting
  static String? debugResolveHostedBase(Uri uri) => _resolveHostedDevBase(uri);
}

class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:4000',
  );
}
