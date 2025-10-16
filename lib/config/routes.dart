import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/jobs/job_detail_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../controllers/chat/chat_detail_bloc.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../screens/unauthorized/unauthorized_screen.dart';
import '../services/role_guard.dart';
import '../services/storage_service.dart';
import '../utils/role_permissions.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
  static const jobDetail = '/job-detail';
  static const chat = '/chat';
  static const unauthorized = '/unauthorized';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case onboarding:
        return MaterialPageRoute<void>(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );
      case login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case signup:
        return MaterialPageRoute<void>(
          builder: (_) => const SignupScreen(),
          settings: settings,
        );
      case dashboard:
        return _guardedRoute(
          settings: settings,
          builder: (_) => const DashboardScreen(),
          requiresAuth: true,
          allowedRoles: RolePermissions.allowedRoles(RolePermission.viewDashboard),
          message: 'Please sign in with an authorized account to access the dashboard.',
        );
      case jobDetail:
        final jobId = settings.arguments as String?;
        if (jobId == null || jobId.isEmpty) {
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Job not found.')),
            ),
            settings: settings,
          );
        }
        return _guardedRoute(
          settings: settings,
          builder: (_) => JobDetailScreen(jobId: jobId),
          requiresAuth: true,
          allowedRoles: RolePermissions.allowedRoles(RolePermission.viewJobs),
          message: 'You do not have permission to view this job.',
        );
      case chat:
        final chatId = settings.arguments as String?;
        final getIt = GetIt.instance;
        if (chatId == null || chatId.isEmpty) {
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Chat not found.')),
            ),
            settings: settings,
          );
        }
        return _guardedRoute(
          settings: settings,
          requiresAuth: true,
          allowedRoles: RolePermissions.allowedRoles(RolePermission.viewChats),
          builder: (_) => BlocProvider<ChatDetailBloc>(
            create: (_) => ChatDetailBloc(
              getIt<ChatService>(),
              getIt<SocketService>(),
            ),
            child: ChatScreen(chatId: chatId),
          ),
          message: 'You do not have permission to open this chat.',
        );
      case unauthorized:
        return MaterialPageRoute<void>(
          builder: (_) => const UnauthorizedScreen(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }

  static Route<dynamic> _guardedRoute({
    required RouteSettings settings,
    required WidgetBuilder builder,
    bool requiresAuth = false,
    Set<String>? allowedRoles,
    String? message,
  }) {
    final getIt = GetIt.instance;
    final storage = getIt<StorageService>();
    final roleGuard = getIt<RoleGuard>();
    final token = storage.token;
    final role = roleGuard.currentRole ?? storage.role;

    final isAuthenticated = token != null && token.isNotEmpty;

    if (requiresAuth && !isAuthenticated) {
      return MaterialPageRoute<void>(
        builder: (_) => UnauthorizedScreen(message: message),
        settings: settings,
      );
    }

    if (allowedRoles != null && allowedRoles.isNotEmpty) {
      if (role == null || !allowedRoles.contains(role)) {
        return MaterialPageRoute<void>(
          builder: (_) => UnauthorizedScreen(
            message: message,
            showLoginButton: !isAuthenticated,
          ),
          settings: settings,
        );
      }
    }

    return MaterialPageRoute<void>(
      builder: builder,
      settings: settings,
    );
  }
}
