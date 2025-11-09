import 'package:flutter/material.dart';

import '../adapters/shared_prefs_store.dart';
import '../config/routes.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/home/presentation/home_page.dart';
import '../services/storage_service.dart';

/// Root widget that decides whether to show the home or login page based on
/// persisted session data.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final Future<bool> _initialSessionCheck;

  @override
  void initState() {
    super.initState();
    _initialSessionCheck = _hasValidSession();
  }

  Future<bool> _hasValidSession() async {
    final store = await SharedPrefsStore.create();
    final storage = StorageService(store);
    final token = storage.token;
    if (token == null || token.isEmpty) {
      return false;
    }
    final expiry = storage.tokenExpiry;
    if (expiry != null && expiry.isBefore(DateTime.now())) {
      await storage.clearAll();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initialSessionCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final isLoggedIn = snapshot.data ?? false;

        return MaterialApp(
          title: 'Freetask',
          onGenerateRoute: onGenerateRoute,
          home: isLoggedIn ? const HomePage() : const LoginPage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
