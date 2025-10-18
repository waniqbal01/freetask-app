const bool _isDebugMode = !bool.fromEnvironment('dart.vm.product');

void appLog(String message, {Object? error, StackTrace? stackTrace}) {
  if (!_isDebugMode) return;
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
