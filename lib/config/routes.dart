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

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
  static const jobDetail = '/job-detail';
  static const chat = '/chat';

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
        return MaterialPageRoute<void>(
          builder: (_) => const DashboardScreen(),
          settings: settings,
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
        return MaterialPageRoute<void>(
          builder: (_) => JobDetailScreen(jobId: jobId),
          settings: settings,
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
        return MaterialPageRoute<void>(
          builder: (_) => BlocProvider<ChatDetailBloc>(
            create: (_) => ChatDetailBloc(
              getIt<ChatService>(),
              getIt<SocketService>(),
            ),
            child: ChatScreen(chatId: chatId),
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
    }
  }
}
