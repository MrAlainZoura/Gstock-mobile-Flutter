import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../models/user/user.dart';

class UserDetailScreen extends StatelessWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Détail utilisateur")),
      body: FutureBuilder<User>(
          future: ApiService().getUserById(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Erreur: ${snapshot.error}"));
            } else if (snapshot.hasData) {
              final user = snapshot.data!; // User
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Nom: ${user.name}", style: const TextStyle(fontSize: 20)),
                    Text("Email: ${user.email}"),
                  ],
                ),
              );
            } else {
              return const Center(child: Text("Aucun utilisateur trouvé"));
            }
          },
        ),
      );
  }
}