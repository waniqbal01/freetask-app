import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'bootstrap/app_bootstrap.dart';
import 'services/monitoring_service.dart';
import 'utils/logger.dart';

Future<void> main() async {
  await bootstrap(() async {
    FlutterError.onError = MonitoringService.recordFlutterError;

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(MonitoringService.recordError(error, stack));
      return false;
    };

    try {
      final bootstrapResult = await AppBootstrap.init();
      return FreetaskApp(bootstrap: bootstrapResult);
    } catch (error, stackTrace) {
      AppLogger.e('Failed to start application', error: error, stackTrace: stackTrace);
      await MonitoringService.recordError(error, stackTrace);
      rethrow;
    }
  });
}
