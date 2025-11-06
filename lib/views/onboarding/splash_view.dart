import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/router/app_router.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_event.dart';
import '../../controllers/auth/auth_state.dart';
import '../../models/user_roles.dart';
import 'login_view.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  static const routeName = AppRoutes.onboarding;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  double _opacity = 0;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _opacity = 1);
      context.read<AuthBloc>().add(const AuthCheckRequested());
    });
  }

  void _handleState(AuthState state) {
    if (!mounted || _navigated) return;
    if (state.status == AuthStatus.authenticated && state.user != null) {
      _navigated = true;
      final route = _routeForRole(state.user!.role);
      Navigator.of(context).pushNamedAndRemoveUntil(
        route,
        (route) => false,
      );
    } else if (state.status == AuthStatus.unauthenticated) {
      _navigated = true;
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginView.routeName,
        (route) => false,
      );
    }
  }

  String _routeForRole(String role) {
    switch (parseUserRole(role)) {
      case UserRoles.freelancer:
      case UserRoles.seller:
      case UserRoles.admin:
      case UserRoles.manager:
      case UserRoles.support:
        return AppRoutes.sellerDashboard;
      case UserRoles.client:
        return AppRoutes.marketplaceHome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) => _handleState(state),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        body: Center(
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: const Duration(milliseconds: 800),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'FT',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Freetask',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
