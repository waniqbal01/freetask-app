import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'controllers/auth/auth_bloc.dart';
import 'controllers/chat/chat_list_bloc.dart';
import 'controllers/job/job_bloc.dart';
import 'controllers/nav/role_nav_cubit.dart';
import 'controllers/theme/theme_cubit.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/chat_cache_service.dart';
import 'services/job_service.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'services/role_guard.dart';
import 'services/socket_service.dart';
import 'services/storage_service.dart';
import 'utils/role_permissions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDependencies();

  runApp(const FreetaskApp());
}

class FreetaskApp extends StatelessWidget {
  const FreetaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final getIt = GetIt.instance;

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(
            getIt<AuthService>(),
            getIt<StorageService>(),
          ),
        ),
        BlocProvider<RoleNavCubit>(
          create: (_) {
            final storage = getIt<StorageService>();
            final initialRole =
                storage.role ?? storage.getUser()?.role ?? UserRoles.defaultRole;
            return RoleNavCubit(initialRole: initialRole);
          },
        ),
        BlocProvider<ThemeCubit>(
          create: (_) {
            final storage = getIt<StorageService>();
            final initialMode = storage.getThemeMode() ?? ThemeMode.system;
            return ThemeCubit(storage, initialMode: initialMode);
          },
        ),
        BlocProvider<JobBloc>(
          create: (_) => JobBloc(
            getIt<JobService>(),
            getIt<StorageService>(),
          ),
        ),
        BlocProvider<ChatListBloc>(
          create: (_) => ChatListBloc(getIt<ChatService>()),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp(
            title: 'Freetask',
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeMode,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            initialRoute: AppRoutes.splash,
          );
        },
      ),
    );
  }
}

Future<void> _configureDependencies() async {
  final getIt = GetIt.instance;
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  final dio = Dio();
  final roleGuard = RoleGuard(storage);
  final apiClient = ApiClient(dio, storage, roleGuard);
  final authService = AuthService(apiClient, storage);
  apiClient.registerRefreshTokenCallback(authService.refreshToken);
  final jobService = JobService(apiClient, roleGuard);
  final profileService = ProfileService(apiClient, storage);
  final chatService = ChatService(apiClient);
  final socketService = SocketService();
  final notificationService = NotificationService(apiClient);
  final chatCacheService = ChatCacheService(prefs);

  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<StorageService>(storage)
    ..registerSingleton<Dio>(dio)
    ..registerSingleton<ApiClient>(apiClient)
    ..registerSingleton<AuthService>(authService)
    ..registerSingleton<JobService>(jobService)
    ..registerSingleton<ProfileService>(profileService)
    ..registerSingleton<ChatService>(chatService)
    ..registerSingleton<ChatCacheService>(chatCacheService)
    ..registerSingleton<SocketService>(socketService)
    ..registerSingleton<NotificationService>(notificationService)
    ..registerSingleton<RoleGuard>(roleGuard);
}
