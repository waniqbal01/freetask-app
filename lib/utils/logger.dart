import 'package:flutter/foundation.dart';

import '../services/monitoring_service.dart';

void appLog(String message, {Object? error, StackTrace? stackTrace}) {
  MonitoringService.instance.log(message, error: error, stackTrace: stackTrace);
  if (!kDebugMode) return;
  // ignore: avoid_print
  print('[Freetask] $message');
  if (error != null) {
    // ignore: avoid_print
    print('Error: $error');
  }
  if (stackTrace != null) {
    // ignore: avoid_print
    print(stackTrace);
  }
}
