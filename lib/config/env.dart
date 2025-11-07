class Env {
  static String get apiBaseUrl =>
      const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:4000');
}
