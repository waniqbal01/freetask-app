import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../controllers/auth/auth_bloc.dart';
import '../controllers/auth/auth_event.dart';
import '../controllers/auth/auth_state.dart';
import '../controllers/nav/role_nav_cubit.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
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
    if (state is AuthAuthenticated) {
      _navigated = true;
      Navigator.of(context).pushNamedAndRemoveUntil(
        DashboardScreen.routeName,
        (route) => false,
        arguments: RoleNavTarget.home,
      );
    } else if (state is AuthUnauthenticated) {
      _navigated = true;
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginScreen.routeName,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) => _handleState(state),
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
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
                    color: theme.colorScheme.primary.withOpacity(0.1),
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
