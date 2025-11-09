import 'package:flutter/material.dart';

import '../../data/models/service_model.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/marketplace/views/marketplace_home_view.dart';
import '../../features/marketplace/views/service_detail_view.dart';
import '../../models/user_roles.dart';
import '../../views/chat/chat_view.dart';
import '../../views/checkout/checkout_view.dart';
import '../../views/common/forbidden_view.dart';
import '../../views/job_detail/job_detail_view.dart';
import '../../views/notification/notifications_view.dart';
import '../../views/onboarding/forgot_password_view.dart';
import '../../views/onboarding/splash_view.dart';
import '../../views/orders/order_detail_view.dart';
import '../../views/profile/profile_view.dart';
import '../../views/seller/create_service_view.dart';
import '../../views/seller/seller_dashboard_view.dart';
import '../../views/wallet/wallet_view.dart';
import 'route_guard.dart';

class AppRoutes {
  static const onboarding = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
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
  AppRouter(this._routeGuard);

  final RouteGuard _routeGuard;

  bool _hasAnyRole(Set<UserRoles> roles) {
    for (final role in roles) {
      if (_routeGuard.hasRole(role)) {
        return true;
      }
    }
    return false;
  }

  Route<dynamic> _guardedRoute(
    RouteSettings settings,
    WidgetBuilder builder, {
    Set<UserRoles> allowedRoles = const {},
  }) {
    if (allowedRoles.isNotEmpty && !_hasAnyRole(allowedRoles)) {
      return MaterialPageRoute<void>(
        builder: (_) => const ForbiddenView(),
        settings: settings,
      );
    }
    return MaterialPageRoute<void>(
      builder: builder,
      settings: settings,
    );
  }

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return _guardedRoute(
          settings,
          (_) => const SplashView(),
        );
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          builder: (_) => const LoginPage(),
          settings: settings,
        );
      case AppRoutes.register:
        return MaterialPageRoute<void>(
          builder: (_) => const RegisterPage(),
          settings: settings,
        );
      case AppRoutes.forgotPassword:
        return MaterialPageRoute<void>(
          builder: (_) => const ForgotPasswordView(),
          settings: settings,
        );
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          builder: (_) => const HomePage(),
          settings: settings,
        );
      case AppRoutes.marketplaceHome:
        return _guardedRoute(
          settings,
          (_) => const MarketplaceHomeView(),
        );
      case AppRoutes.sellerDashboard:
        return _guardedRoute(
          settings,
          (_) => const SellerDashboardView(),
          allowedRoles: const {
            UserRoles.seller,
            UserRoles.admin,
            UserRoles.manager,
            UserRoles.support,
          },
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
          return _guardedRoute(
            settings,
            (_) => CheckoutView(
              orderId: checkoutArgs.orderId,
              amountCents: checkoutArgs.amountCents,
              email: checkoutArgs.email,
            ),
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
        return _guardedRoute(
          settings,
          (_) => OrderDetailView(orderId: orderId),
        );
      case AppRoutes.createService:
        final serviceArg = settings.arguments;
        final initialService = serviceArg is Service ? serviceArg : null;
        return _guardedRoute(
          settings,
          (_) => CreateServiceView(initialService: initialService),
          allowedRoles: const {
            UserRoles.seller,
            UserRoles.admin,
            UserRoles.manager,
            UserRoles.support,
          },
        );
      case AppRoutes.jobDetail:
        final jobId = settings.arguments as String?;
        return _guardedRoute(
          settings,
          (_) => JobDetailView(jobId: jobId ?? ''),
        );
      case AppRoutes.chat:
        return _guardedRoute(
          settings,
          (_) => const ChatView(),
        );
      case AppRoutes.wallet:
        return _guardedRoute(
          settings,
          (_) => const WalletView(),
        );
      case AppRoutes.notifications:
        return _guardedRoute(
          settings,
          (_) => const NotificationsView(),
        );
      case AppRoutes.profile:
        return _guardedRoute(
          settings,
          (_) => const ProfileView(),
        );
      default:
        return _guardedRoute(
          settings,
          (_) => const SplashView(),
        );
    }
  }
}
