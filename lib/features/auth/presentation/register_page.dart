import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  static const route = '/register';

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: Text('Daftar')),
      body: Center(child: Text('Halaman daftar (akan diisi kemudian)')),
    );
  }
}
