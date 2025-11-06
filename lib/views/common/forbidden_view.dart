import 'package:flutter/material.dart';

class ForbiddenView extends StatelessWidget {
  const ForbiddenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tidak dibenarkan')),
      body: const Center(
        child: Text('Anda tidak mempunyai akses ke halaman ini.'),
      ),
    );
  }
}
