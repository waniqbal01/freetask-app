import 'package:flutter/material.dart';

import '../views/chat/chat_view.dart';
import '../views/dashboard_client/dashboard_client_view.dart';
import '../views/dashboard_freelancer/dashboard_freelancer_view.dart';
import '../views/job_detail/job_detail_view.dart';
import '../views/notification/notifications_view.dart';
import '../views/onboarding/login_view.dart';
import '../views/onboarding/forgot_password_view.dart';
import '../views/onboarding/splash_view.dart';
import '../views/profile/profile_view.dart';
import '../views/wallet/wallet_view.dart';

class AppRoutes {
  static const onboarding = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const dashboard = '/dashboard';
  static const freelancerDashboard = '/dashboard/freelancer';
  static const jobDetail = '/job-detail';
  static const chat = '/chat';
  static const wallet = '/wallet';
  static const notifications = '/notifications';
  static const profile = '/profile';
}

class AppRouter {
  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashView(),
          settings: settings,
        );
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginView(),
          settings: settings,
        );
      case AppRoutes.forgotPassword:
        return MaterialPageRoute<void>(
          builder: (_) => const ForgotPasswordView(),
          settings: settings,
        );
      case AppRoutes.dashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const DashboardClientView(),
          settings: settings,
        );
      case AppRoutes.freelancerDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const DashboardFreelancerView(),
          settings: settings,
        );
      case AppRoutes.jobDetail:
        final jobId = settings.arguments as String?;
        return MaterialPageRoute<void>(
          builder: (_) => JobDetailView(jobId: jobId ?? ''),
          settings: settings,
        );
      case AppRoutes.chat:
        return MaterialPageRoute<void>(
          builder: (_) => const ChatView(),
          settings: settings,
        );
      case AppRoutes.wallet:
        return MaterialPageRoute<void>(
          builder: (_) => const WalletView(),
          settings: settings,
        );
      case AppRoutes.notifications:
        return MaterialPageRoute<void>(
          builder: (_) => const NotificationsView(),
          settings: settings,
        );
      case AppRoutes.profile:
        return MaterialPageRoute<void>(
          builder: (_) => const ProfileView(),
          settings: settings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashView(),
          settings: settings,
        );
    }
  }
}
