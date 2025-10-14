import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'controllers/auth/auth_bloc.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';

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
      ],
      child: MaterialApp(
        title: 'Freetask',
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.system,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        initialRoute: AppRoutes.splash,
      ),
    );
  }
}

Future<void> _configureDependencies() async {
  final getIt = GetIt.instance;
  final prefs = await SharedPreferences.getInstance();
  final storage = StorageService(prefs);
  final dio = Dio();
  final apiClient = ApiClient(dio, storage);
  final authService = AuthService(apiClient, storage);

  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<StorageService>(storage)
    ..registerSingleton<Dio>(dio)
    ..registerSingleton<ApiClient>(apiClient)
    ..registerSingleton<AuthService>(authService);
}
