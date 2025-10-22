import 'package:flutter/foundation.dart';

import '../services/monitoring_service.dart';

class AppLogger {
  const AppLogger._();

  static void d(String message, {Object? error, StackTrace? stackTrace}) {
    _log('DEBUG', message, error: error, stackTrace: stackTrace);
  }

  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace);
  }

  static void _log(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    MonitoringService.instance.log(
      '[$level] $message',
      error: error,
      stackTrace: stackTrace,
    );
    if (!kDebugMode) {
      return;
    }
    final buffer = StringBuffer('[Freetask][$level] $message');
    debugPrint(buffer.toString());
    if (error != null) {
      debugPrint('└─ error: $error');
    }
    if (stackTrace != null) {
      debugPrint('└─ stackTrace: $stackTrace');
    }
  }
}
