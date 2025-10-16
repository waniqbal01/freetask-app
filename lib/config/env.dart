class Env {
  const Env._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://backend/api',
  );

  static const String socketBase = String.fromEnvironment(
    'SOCKET_BASE',
    defaultValue: 'https://backend',
  );
}
