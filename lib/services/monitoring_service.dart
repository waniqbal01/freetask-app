import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:freetask_app/config/app_env.dart';

class MonitoringService {
  MonitoringService._();

  static String? _latestRequestId;

  static Future<void> init() async {
    if (!AppEnv.enableSentry || AppEnv.sentryDsn.isEmpty) {
      return;
    }
    // Additional initialization is handled during application bootstrap.
  }

  static void updateRequestContext(String? requestId) {
    _latestRequestId = requestId;
  }

  static Future<void> recordError(Object error, StackTrace? stackTrace) {
    return Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (_latestRequestId != null) {
          scope.setTag('requestId', _latestRequestId!);
        }
      },
    );
  }

  static void log(String message, {Object? error, StackTrace? stackTrace}) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'log',
        message: message,
        level: SentryLevel.info,
        data: <String, String?>{
          if (error != null) 'error': error.toString(),
          if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        },
      ),
    );
  }

  static void recordFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  }
}
