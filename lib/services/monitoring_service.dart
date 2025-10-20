import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env.dart';

class MonitoringService {
  MonitoringService._();

  static final MonitoringService instance = MonitoringService._();

  bool _crashlyticsReady = false;
  String? _latestRequestId;

  Future<void> bootstrap(Future<void> Function() appRunner) async {
    await SentryFlutter.init(
      (options) {
        options.dsn = Env.sentryDsn;
        options.environment = Env.appEnvironment;
        options.release = Env.appRelease;
        options.tracesSampleRate = 1.0;
        options.beforeSend = (event, {hint}) {
          if ((event.tags?['requestId'] ?? '').isEmpty && _latestRequestId != null) {
            return event.copyWith(
              tags: {
                ...?event.tags,
                'requestId': _latestRequestId!,
                'environment': Env.appEnvironment,
                'release': Env.appRelease,
              },
            );
          }
          return event;
        };
      },
      appRunner: () async {
        await _initialiseCrashlytics();
        await appRunner();
      },
    );
  }

  Future<void> _initialiseCrashlytics() async {
    if (kIsWeb) {
      return;
    }
    final options = _firebaseOptionsFromEnv();
    if (options == null) {
      debugPrint('[Monitoring] Firebase options missing, Crashlytics disabled');
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      await FirebaseCrashlytics.instance.setCustomKey('release', Env.appRelease);
      await FirebaseCrashlytics.instance.setCustomKey('environment', Env.appEnvironment);
      _crashlyticsReady = true;
    } catch (error, stackTrace) {
      debugPrint('[Monitoring] Crashlytics init failed: $error');
      await Sentry.captureException(error, stackTrace: stackTrace);
    }
  }

  void updateRequestContext(String? requestId) {
    _latestRequestId = requestId;
    if (!_crashlyticsReady || requestId == null || requestId.isEmpty) {
      return;
    }
    unawaited(FirebaseCrashlytics.instance.setCustomKey('requestId', requestId));
  }

  Future<void> recordError(Object error, StackTrace stackTrace) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (_latestRequestId != null) {
          scope.setTag('requestId', _latestRequestId!);
        }
        scope.setTag('environment', Env.appEnvironment);
        scope.setTag('release', Env.appRelease);
      },
    );
    if (_crashlyticsReady) {
      await FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }

  void log(String message, {Object? error, StackTrace? stackTrace}) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'log',
        message: message,
        level: SentryLevel.info,
        data: {
          if (error != null) 'error': error.toString(),
          if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        },
      ),
    );
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.log(message);
      if (error != null) {
        unawaited(FirebaseCrashlytics.instance.recordError(error, stackTrace ?? StackTrace.current));
      }
    }
  }

  FirebaseOptions? _firebaseOptionsFromEnv() {
    if (Env.firebaseApiKey.isEmpty ||
        Env.firebaseAppId.isEmpty ||
        Env.firebaseProjectId.isEmpty ||
        Env.firebaseMessagingSenderId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: Env.firebaseApiKey,
      appId: Env.firebaseAppId,
      projectId: Env.firebaseProjectId,
      messagingSenderId: Env.firebaseMessagingSenderId,
      storageBucket: Env.firebaseStorageBucket.isEmpty ? null : Env.firebaseStorageBucket,
      measurementId: Env.firebaseMeasurementId.isEmpty ? null : Env.firebaseMeasurementId,
    );
  }
}
