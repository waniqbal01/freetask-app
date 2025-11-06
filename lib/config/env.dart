import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class Env {
  static String get apiBaseUrl {
    // Allow override via --dart-define=API_BASE_URL=...
    // Default per platform for local dev.
    if (kIsWeb) {
      return const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:4000');
    }
    try {
      if (Platform.isAndroid) {
        return const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:4000');
      }
      if (Platform.isIOS || Platform.isMacOS) {
        return const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:4000');
      }
    } catch (_) {
      // Platform not available (e.g., web); already handled above.
    }
    return const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:4000');
  }
}
