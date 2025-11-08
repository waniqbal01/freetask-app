import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth/firebase_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final auth = FirebaseAuthService();
  runApp(MyApp(auth: auth));
}

class MyApp extends StatelessWidget {
  final FirebaseAuthService auth;
  const MyApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freetask',
      home: AuthGate(auth: auth),
    );
  }
}

class AuthGate extends StatelessWidget {
  final FirebaseAuthService auth;
  const AuthGate({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: auth.onAuthStateChanged,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (auth.isSignedIn) {
          return const Scaffold(body: Center(child: Text('Dashboard')));
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Gantikan dengan UI sebenar anda – ini placeholder ringkas
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Center(child: Text('TODO: implement login form')),
    );
  }
}
