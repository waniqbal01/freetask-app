import 'package:flutter/material.dart';
import 'config/routes.dart';
import 'package:freetask_app/features/auth/presentation/login_page.dart';
import 'package:freetask_app/features/home/presentation/home_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = false; // TODO: sambungkan dengan semakan token sebenar
    return MaterialApp(
      title: 'Freetask',
      onGenerateRoute: onGenerateRoute,
      initialRoute: isLoggedIn ? HomePage.route : LoginPage.route,
      debugShowCheckedModeBanner: false,
    );
  }
}
