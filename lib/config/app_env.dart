class AppEnv {
  static const apiBaseUrl = 'http://10.0.2.2:3000';
  static const sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'Freetask');
  static const enableSentry =
      bool.fromEnvironment('ENABLE_SENTRY', defaultValue: false);
}
