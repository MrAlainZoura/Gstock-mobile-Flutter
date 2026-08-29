import 'package:flutter/material.dart';

import 'api/session_guard.dart';
import 'pages/auth_gate.dart';
import 'pages/login_page.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'GStock Mobile',
      theme: buildAppTheme(),
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginPage(),
      },
    );
  }
}
