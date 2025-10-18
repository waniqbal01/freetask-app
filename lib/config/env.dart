class Env {
  const Env._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:8080/api',
  );

  static const String socketBase = String.fromEnvironment(
    'SOCKET_BASE',
    defaultValue: 'http://localhost:8080',
  );
}
