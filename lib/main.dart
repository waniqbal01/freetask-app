import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'services/monitoring_service.dart';
import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MonitoringService.instance.bootstrap(() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      MonitoringService.instance
          .recordError(details.exception, details.stack ?? StackTrace.empty);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(MonitoringService.instance.recordError(error, stack));
      return false;
    };

    try {
      final bootstrap = await AppBootstrap.init();
      runApp(FreetaskApp(bootstrap: bootstrap));
    } catch (error, stackTrace) {
      AppLogger.e('Failed to start application', error: error, stackTrace: stackTrace);
      await MonitoringService.instance.recordError(error, stackTrace);
      rethrow;
    }
  });
}
