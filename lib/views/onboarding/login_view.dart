import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_event.dart';
import '../../controllers/auth/auth_state.dart';
import '../../controllers/nav/role_nav_cubit.dart';
import '../../utils/role_permissions.dart';

enum _AuthFormType { login, signup }

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  static const routeName = AppRoutes.login;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  _AuthFormType _formType = _AuthFormType.login;
  String _selectedRole = UserRoles.client;
  bool _loginPasswordVisible = false;
  bool _signupPasswordVisible = false;
  bool _signupConfirmPasswordVisible = false;

  static final _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _isLoginForm => _formType == _AuthFormType.login;

  @override
  void dispose() {
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
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegExp.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _goToForgotPassword() {
    Navigator.of(context).pushNamed(AppRoutes.forgotPassword);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.message != current.message ||
          previous.status != current.status,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.message != null) {
          final isError = state.message!.isError;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message!.text),
                behavior: SnackBarBehavior.floating,
                backgroundColor: isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            );
        }

        if (state.status == AuthStatus.authenticated && state.user != null) {
          context.read<RoleNavCubit>().updateRole(state.user!.role);
          final route = state.user!.role == UserRoles.freelancer
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
        final isLoginLoading = state.isLoading && state.flow == AuthFlow.login;
        final isSignupLoading = state.isLoading && state.flow == AuthFlow.signup;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final horizontalPadding = isWide ? 56.0 : 24.0;
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 32,
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
                          color: Colors.black.withAlpha(5), // Corrected method
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
                          height: 480,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Form(
                                  key: _loginFormKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Import statements should be at the top of the file
                                      import 'package:your_package_name/input_field.dart'; // Ensure to replace with the actual package name
                                      
                                                                            InputField(
                                                                              controller: _loginEmailController,
                                                                              label: 'Email',
                                                                              hint: 'you@example.com',
                                                                              keyboardType:
                                                                                  TextInputType.emailAddress,
                                                                              validator: _validateEmail,
                                                                              autofillHints: const [
                                                                                AutofillHints.email,
                                                                              ],
                                                                            ),
                                      const SizedBox(height: 16),
                                      InputField(
                                        controller: _loginPasswordController,
                                        label: 'Password',
                                        obscureText: !_loginPasswordVisible,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Password is required';
                                          }
                                          if (value.length < 6) {
                                            return 'Use at least 6 characters';
                                          }
                                          return null;
                                        },
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _loginPasswordVisible
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _loginPasswordVisible =
                                                  !_loginPasswordVisible;
                                            });
                                          },
                                        ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        autofillHints: const [
                                          AutofillHints.name,
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      InputField(
                                        controller: _signupEmailController,
                                        label: 'Email',
                                        hint: 'you@example.com',
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: _validateEmail,
                                        autofillHints: const [
                                          AutofillHints.email,
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      InputField(
                                        controller: _signupPasswordController,
                                        label: 'Password',
                                        obscureText: !_signupPasswordVisible,
                                        validator: (value) {
                                          if (value == null ||
                                              value.length < 6) {
                                            return 'Use at least 6 characters';
                                          }
                                          return null;
                                        },
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _signupPasswordVisible
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _signupPasswordVisible =
                                                  !_signupPasswordVisible;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      InputField(
                                        controller:
                                            _signupConfirmPasswordController,
                                        label: 'Confirm Password',
                                        obscureText:
                                            !_signupConfirmPasswordVisible,
                                        validator:
                                            _validatePasswordConfirmation,
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.newPassword,
                                        ],
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
                                      const SizedBox(height: 16),
                                      Text(
                                        'Role',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedRole,
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                                              setState(
                                                  () => _selectedRole = value);
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
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed: _goToForgotPassword,
                              child: const Text('Forgot your password?'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool showLoading) {
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
          'Collaborate effortlessly with clients and freelancers in a single secure workspace.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: showLoading
              ? LinearProgressIndicator(
                  key: const ValueKey('header-progress'),
                  minHeight: 4,
                )
              : const SizedBox(key: ValueKey('header-empty'), height: 4),
        ),
      ],
    );
  }

  Widget _buildSwitcher(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          _SwitcherButton(
            label: 'Log in',
            selected: _isLoginForm,
            onTap: () => setState(() => _formType = _AuthFormType.login),
          ),
          _SwitcherButton(
            label: 'Sign up',
            selected: !_isLoginForm,
            onTap: () => setState(() => _formType = _AuthFormType.signup),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(
    ThemeData theme,
    AuthBloc bloc,
    bool isLoading,
  ) {
    return DecoratedBox(
      key: const ValueKey('login-form'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 6) {
                    return 'Use at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _submitLogin(bloc),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
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

  Widget _buildSignupForm(
    ThemeData theme,
    AuthBloc bloc,
    bool isLoading,
  ) {
    return DecoratedBox(
      key: const ValueKey('signup-form'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
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
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Use at least 6 characters';
                  }
                  return null;
                },
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your password';
                  }
                  if (value != _signupPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
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
                decoration: const InputDecoration(
                  labelText: 'Choose your role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _submitSignup(bloc),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
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
}

class _SwitcherButton extends StatelessWidget {
  const _SwitcherButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: theme.shadowColor.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
