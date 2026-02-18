import 'package:flutter/material.dart';
import 'pages/user_index.dart'; // ton écran liste

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // enlever la bannière rouge
      title: 'GStock Mobile',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const UserListScreen(), // 🚀 Charger la liste au démarrage
    );
  }
}