import 'package:flutter/material.dart';

import '../views/chat/chat_view.dart';
import '../views/job_detail/job_detail_view.dart';
import '../views/notification/notifications_view.dart';
import '../views/onboarding/login_view.dart';
import '../views/onboarding/forgot_password_view.dart';
import '../views/onboarding/splash_view.dart';
import '../views/profile/profile_view.dart';
import '../views/wallet/wallet_view.dart';
import '../views/marketplace/marketplace_home_view.dart';
import '../views/marketplace/service_detail_view.dart';
import '../views/checkout/checkout_view.dart';
import '../views/orders/order_detail_view.dart';
import '../views/seller/create_service_view.dart';
import '../views/seller/seller_dashboard_view.dart';
import '../models/service.dart';

class AppRoutes {
  static const onboarding = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const marketplaceHome = '/marketplace';
  static const sellerDashboard = '/seller';
  static const serviceDetail = '/marketplace/service';
  static const checkout = '/checkout';
  static const orderDetail = '/orders/detail';
  static const createService = '/seller/create-service';
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
      case AppRoutes.marketplaceHome:
        return MaterialPageRoute<void>(
          builder: (_) => const MarketplaceHomeView(),
          settings: settings,
        );
      case AppRoutes.sellerDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const SellerDashboardView(),
          settings: settings,
        );
      case AppRoutes.serviceDetail:
        final detailArgs = settings.arguments;
        if (detailArgs is ServiceDetailViewArgs) {
          return MaterialPageRoute<void>(
            builder: (_) => ServiceDetailView(
              serviceId: detailArgs.serviceId,
              initialService: detailArgs.prefetchedService,
            ),
            settings: settings,
          );
        }
        final serviceId = detailArgs?.toString() ?? '';
        return MaterialPageRoute<void>(
          builder: (_) => ServiceDetailView(serviceId: serviceId),
          settings: settings,
        );
      case AppRoutes.checkout:
        final checkoutArgs = settings.arguments;
        if (checkoutArgs is CheckoutViewArgs) {
          return MaterialPageRoute<void>(
            builder: (_) => CheckoutView(
              orderId: checkoutArgs.orderId,
              amountCents: checkoutArgs.amountCents,
              email: checkoutArgs.email,
            ),
            settings: settings,
          );
        }
        throw ArgumentError('CheckoutView requires CheckoutViewArgs');
      case AppRoutes.orderDetail:
        final orderArgs = settings.arguments;
        if (orderArgs is OrderDetailViewArgs) {
          return MaterialPageRoute<void>(
            builder: (_) => OrderDetailView(
              orderId: orderArgs.orderId,
              clientId: orderArgs.clientId,
              isEditable: orderArgs.isEditable,
            ),
            settings: settings,
          );
        }
        final orderId = orderArgs?.toString() ?? '';
        return MaterialPageRoute<void>(
          builder: (_) => OrderDetailView(orderId: orderId),
          settings: settings,
        );
      case AppRoutes.createService:
        final serviceArg = settings.arguments;
        final initialService = serviceArg is Service ? serviceArg : null;
        return MaterialPageRoute<void>(
          builder: (_) => CreateServiceView(initialService: initialService),
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
