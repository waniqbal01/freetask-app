import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:freetask_app/config/routes.dart';
import 'package:freetask_app/core/router/app_router.dart';
import 'package:freetask_app/features/auth/presentation/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const route = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

      final res = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': _email.text.trim(),
          'password': _password.text,
        },
        options: Options(validateStatus: (status) => status != null && status < 500),
      );

      final statusCode = res.statusCode ?? 500;
      if (statusCode != 200) {
        final data = res.data;
        final message = data != null && data['message'] != null
            ? data['message'].toString()
            : 'Gagal log masuk (kod $statusCode)';
        throw Exception(message);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berjaya log masuk')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final response = e.response;
      final data = response?.data;
      late final String message;
      if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      } else if (response?.statusCode != null) {
        message = 'Gagal log masuk (kod ${response!.statusCode})';
      } else {
        message = 'Tidak dapat menghubungi pelayan';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@example.com',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email diperlukan';
                      if (!v.contains('@')) return 'Format email tidak sah';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Kata laluan',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                        tooltip: _obscure ? 'Tunjuk' : 'Sembunyi',
                      ),
                    ),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Kata laluan diperlukan';
                      if (v.length < 6) return 'Min 6 aksara';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Log Masuk'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            Navigator.of(context).pushNamed(RegisterPage.route);
                          },
                    child: const Text('Belum ada akaun? Daftar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
