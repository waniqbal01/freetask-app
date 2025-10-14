import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes.dart';
import '../../controllers/auth/auth_bloc.dart';
import '../../controllers/auth/auth_event.dart';
import '../../controllers/auth/auth_state.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_snackbar.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'client';
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null) return;
    setState(() => _submitted = true);
    if (!form.validate()) {
      return;
    }
    context.read<AuthBloc>().add(
          SignupSubmitted(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: _role,
          ),
        );
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        } else if (state is AuthError) {
          showAppSnackBar(context, state.message, isError: true);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return Scaffold(
          appBar: AppBar(title: const Text('Create account')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join Freetask',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create an account to hire or work on amazing jobs.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    AppInput(
                      controller: _nameController,
                      label: 'Full name',
                      hintText: 'John Doe',
                      textInputAction: TextInputAction.next,
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _emailController,
                      label: 'Email',
                      hintText: 'name@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _passwordController,
                      label: 'Password',
                      hintText: 'At least 6 characters',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: Validators.validatePassword,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'client',
                          child: Text('Client'),
                        ),
                        DropdownMenuItem(
                          value: 'freelancer',
                          child: Text('Freelancer'),
                        ),
                      ],
                      onChanged: isLoading
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _role = value);
                              }
                            },
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: 'Sign up',
                      onPressed: _submit,
                      isLoading: isLoading,
                      icon: Icons.person_add,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: isLoading ? null : _goToLogin,
                      child: const Text('Already have an account? Log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
