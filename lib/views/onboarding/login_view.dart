import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_event.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/nav/role_nav_cubit.dart';
import '../../models/user_roles.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  static const routeName = AppRoutes.login;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  bool _loginPasswordVisible = false;
  bool _signupPasswordVisible = false;
  bool _signupConfirmPasswordVisible = false;
  String _selectedRole = UserRoles.client.name;

  static final _emailRegExp = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

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
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  void _submitLogin(AuthBloc bloc) {
    if (!(_loginFormKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    bloc.add(
      LoginRequested(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      ),
    );
  }

  void _submitSignup(AuthBloc bloc) {
    if (!(_signupFormKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    bloc.add(
      SignupRequested(
        name: _signupNameController.text.trim(),
        email: _signupEmailController.text.trim(),
        password: _signupPasswordController.text,
        role: _selectedRole,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegExp.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Use at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }
    if (value != _signupPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  void _goToForgotPassword() {
    Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.user != current.user,
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated && state.user != null) {
          context.read<RoleNavCubit>().updateRole(state.user!.role);
          final route = _routeForRole(state.user!.role);
          Navigator.of(context).pushNamedAndRemoveUntil(
            route,
            (route) => false,
          );
        }
      },
      builder: (context, state) {
        if (state.status == AuthStatus.unknown) {
          return const _FullScreenLoader();
        }

        final authBloc = context.read<AuthBloc>();
        final isLoginLoading =
            state.isLoading && state.flow == AuthFlow.login;
        final isSignupLoading =
            state.isLoading && state.flow == AuthFlow.signup;
        final isCheckingSession =
            state.isLoading && state.flow == AuthFlow.general;
        final authMessage = state.message;

        return Stack(
          children: [
            Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(Theme.of(context), isLoginLoading || isSignupLoading),
                          const SizedBox(height: 24),
                          if (authMessage != null)
                            _StatusBanner(message: authMessage),
                          if (authMessage != null) const SizedBox(height: 16),
                          _buildTabSwitcher(Theme.of(context)),
                          const SizedBox(height: 16),
                          _buildTabView(
                            bloc: authBloc,
                            isLoginLoading: isLoginLoading,
                            isSignupLoading: isSignupLoading,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: isLoginLoading || isSignupLoading
                                  ? null
                                  : _goToForgotPassword,
                              child: const Text('Forgot your password?'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (isCheckingSession) const _FullScreenLoader(),
          ],
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool showProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to Freetask',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Post jobs, collaborate, and manage work seamlessly in one space.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: showProgress
              ? LinearProgressIndicator(
                  key: const ValueKey('login-progress'),
                  minHeight: 4,
                )
              : const SizedBox(key: ValueKey('login-idle'), height: 4),
        ),
      ],
    );
  }

  Widget _buildTabSwitcher(ThemeData theme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TabBar(
        controller: _tabController,
        splashFactory: NoSplash.splashFactory,
        indicator: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor:
            theme.colorScheme.onSurface.withValues(alpha: 0.6),
        tabs: const [
          Tab(text: 'Log in'),
          Tab(text: 'Sign up'),
        ],
      ),
    );
  }

  Widget _buildTabView({
    required AuthBloc bloc,
    required bool isLoginLoading,
    required bool isSignupLoading,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: 420,
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildLoginForm(bloc, isLoginLoading),
            _buildSignupForm(bloc, isSignupLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthBloc bloc, bool isLoading) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _loginFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _loginEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _loginPasswordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _loginPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _loginPasswordVisible = !_loginPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_loginPasswordVisible,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                validator: _validatePassword,
                onFieldSubmitted: (_) =>
                    isLoading ? null : _submitLogin(bloc),
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _submitLogin(bloc),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Log in'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm(AuthBloc bloc, bool isLoading) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _signupFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _signupNameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _signupEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _signupPasswordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _signupPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _signupPasswordVisible = !_signupPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_signupPasswordVisible,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: _validatePassword,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _signupConfirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _signupConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _signupConfirmPasswordVisible =
                            !_signupConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_signupConfirmPasswordVisible,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: _validateConfirmPassword,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Choose your role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: [
                  DropdownMenuItem(
                    value: UserRoles.client.name,
                    child: const Text('Client'),
                  ),
                  DropdownMenuItem(
                    value: UserRoles.freelancer.name,
                    child: const Text('Freelancer'),
                  ),
                ],
                onChanged: isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _submitSignup(bloc),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Create account'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerLow
          .withValues(alpha: 0.85),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final AuthMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = message.isError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? theme.colorScheme.error.withValues(alpha: 0.12)
            : theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? theme.colorScheme.error.withValues(alpha: 0.4)
              : theme.colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
