class Env {
  const Env._();

  static const apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://freetask-backend.onrender.com/api',
  );

  static const socketBase = String.fromEnvironment(
    'SOCKET_BASE',
    defaultValue: 'https://freetask-backend.onrender.com',
  );
}
