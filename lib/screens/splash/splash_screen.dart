import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_event.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/nav/role_nav_cubit.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/app_snackbar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<AuthBloc>().add(const AuthCheckRequested()),
    );
  }

  void _handleNavigation(BuildContext context, AuthState state) {
    if (_navigated) return;
    if (state is AuthAuthenticated) {
      context.read<RoleNavCubit>().updateRole(state.user.role);
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    } else if (state is AuthUnauthenticated) {
      context.read<RoleNavCubit>().updateRole(UserRoles.defaultRole);
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
    } else if (state is AuthError) {
      showAppSnackBar(context, state.message, isError: true);
      _navigated = true;
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthAuthenticated ||
          current is AuthUnauthenticated ||
          current is AuthError,
      listener: _handleNavigation,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.task_alt,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Freetask',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
