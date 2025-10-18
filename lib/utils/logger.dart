import 'package:flutter/foundation.dart';

void appLog(String message, {Object? error, StackTrace? stackTrace}) {
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
