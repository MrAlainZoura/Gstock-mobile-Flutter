import 'package:flutter/material.dart';
import 'pages/user/user_index.dart'; 
import 'pages/user/user_show.dart'; 
import 'pages/user_form.dart';
import 'pages/home.dart';

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
      home: const HomePage(), // 🚀 Charger la liste au démarrage
      // home: const UserListScreen(), // 🚀 Charger la liste au démarrage
      // home: const UserFormScreen(),
      // home: const UserDetailScreen(userId: 1) ,
    );
  }
}