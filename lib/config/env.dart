class Env {
  static const String apiBase =
      String.fromEnvironment('API_BASE', defaultValue: 'https://api.freetask.my');
  static const String socketBase =
      String.fromEnvironment('SOCKET_BASE', defaultValue: 'https://api.freetask.my');
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'beta');
  static const String appRelease = String.fromEnvironment('APP_RELEASE', defaultValue: 'freetask-app@dev');
}
