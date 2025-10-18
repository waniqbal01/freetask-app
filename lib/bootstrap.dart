import 'package:dio/dio.dart';

import 'adapters/shared_prefs_store.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/role_guard.dart';
import 'services/storage_service.dart';

/// Provides a convenient entry point for Flutter applications to configure the
/// pure Dart services used by the package. The bootstrap ensures that the
/// refresh-token flow is wired up and the shared preferences adapter is used
/// for persistence.
class AppBootstrap {
  const AppBootstrap._({
    required this.apiClient,
    required this.authService,
    required this.storageService,
    required this.roleGuard,
  });

  /// Configures the service layer with real platform implementations.
  static Future<AppBootstrap> initialize() async {
    final store = await SharedPrefsStore.create();
    final storage = StorageService(store);
    final roleGuard = RoleGuard(storage);
    final apiClient = ApiClient(Dio(), storage, roleGuard);
    final authService = AuthService(apiClient, storage);
    apiClient.setRefreshCallback(() async => authService.refreshToken());

    return AppBootstrap._(
      apiClient: apiClient,
      authService: authService,
      storageService: storage,
      roleGuard: roleGuard,
    );
  }

  final ApiClient apiClient;
  final AuthService authService;
  final StorageService storageService;
  final RoleGuard roleGuard;
}
