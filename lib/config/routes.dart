class ApiConfig {
  // API asas anda – ubah dengan --dart-define=API_BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:4000',
  );
}
