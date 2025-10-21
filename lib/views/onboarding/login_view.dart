import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_event.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/nav/role_nav_cubit.dart';
import '../../utils/role_permissions.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  static const routeName = AppRoutes.login;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  late final TabController _tabController;
  String _selectedRole = UserRoles.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  void _onLogin(AuthBloc bloc) {
    if (_loginFormKey.currentState?.validate() ?? false) {
      bloc.add(
        LoginSubmitted(
          email: _loginEmailController.text.trim(),
          password: _loginPasswordController.text,
        ),
      );
    }
  }

  void _onSignup(AuthBloc bloc) {
    if (_signupFormKey.currentState?.validate() ?? false) {
      bloc.add(
        SignupSubmitted(
          name: _signupNameController.text.trim(),
          email: _signupEmailController.text.trim(),
          password: _signupPasswordController.text,
          role: _selectedRole,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is AuthAuthenticated) {
          context.read<RoleNavCubit>().updateRole(state.user.role);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Welcome back, ${state.user.name}!')),
          );
          final route = state.user.role == UserRoles.freelancer
              ? AppRoutes.freelancerDashboard
              : AppRoutes.dashboard;
          Navigator.of(context).pushNamedAndRemoveUntil(
            route,
            (route) => false,
            arguments: RoleNavTarget.home,
          );
        }
      },
      builder: (context, state) {
        final authBloc = context.read<AuthBloc>();
        final isLoading = state is AuthLoading;
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Freetask',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Post jobs, collaborate, and stay on top of your work in one minimalist workspace.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          labelColor: theme.colorScheme.primary,
                          unselectedLabelColor: Colors.grey.shade500,
                          indicatorColor: theme.colorScheme.primary,
                          labelStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(text: 'Login'),
                            Tab(text: 'Register'),
                          ],
                        ),
                        const Divider(height: 1),
                        SizedBox(
                          height: 420,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Form(
                                  key: _loginFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InputField(
                                        controller: _loginEmailController,
                                        label: 'Email',
                                        hint: 'you@example.com',
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Email is required';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      InputField(
                                        controller: _loginPasswordController,
                                        label: 'Password',
                                        obscureText: true,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Password is required';
                                          }
                                          return null;
                                        },
                                        textInputAction: TextInputAction.done,
                                      ),
                                      const Spacer(),
                                      CustomButton(
                                        label: 'Login',
                                        loading: isLoading,
                                        onPressed: () => _onLogin(authBloc),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Form(
                                  key: _signupFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      InputField(
                                        controller: _signupNameController,
                                        label: 'Full Name',
                                        hint: 'Jane Cooper',
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Name is required';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      InputField(
                                        controller: _signupEmailController,
                                        label: 'Email',
                                        hint: 'you@example.com',
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Email is required';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      InputField(
                                        controller: _signupPasswordController,
                                        label: 'Password',
                                        obscureText: true,
                                        validator: (value) {
                                          if (value == null || value.length < 6) {
                                            return 'Use at least 6 characters';
                                          }
                                          return null;
                                        },
                                        textInputAction: TextInputAction.done,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Role',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedRole,
                                            borderRadius: BorderRadius.circular(12),
                                            items: const [
                                              DropdownMenuItem(
                                                value: UserRoles.client,
                                                child: Text('Client'),
                                              ),
                                              DropdownMenuItem(
                                                value: UserRoles.freelancer,
                                                child: Text('Freelancer'),
                                              ),
                                            ],
                                            onChanged: (value) {
                                              if (value == null) return;
                                              setState(() => _selectedRole = value);
                                            },
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      CustomButton(
                                        label: 'Create account',
                                        loading: isLoading,
                                        onPressed: () => _onSignup(authBloc),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
