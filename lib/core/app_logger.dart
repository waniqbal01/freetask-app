import 'dart:developer' as dev;

class AppLogger {
  static void d(String msg) => dev.log(msg, name: 'DEBUG');
  static void i(String msg) => dev.log(msg, name: 'INFO');
  static void w(String msg) => dev.log(msg, name: 'WARN');
  static void e(String msg, [Object? error, StackTrace? stack]) =>
      dev.log(msg, name: 'ERROR', error: error, stackTrace: stack);
}
