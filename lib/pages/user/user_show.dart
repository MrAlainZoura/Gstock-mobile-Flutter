import 'package:flutter/material.dart';

import '../../api/user_service.dart';
import '../../models/user.dart';
import '../../utils/access.dart';
import 'edit.dart';

class UserDetailScreen extends StatelessWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Access>(
      future: Access.load(),
      builder: (context, accessSnap) {
        final access = accessSnap.data ?? Access();
        return Scaffold(
          appBar: AppBar(
            title: const Text("Détail utilisateur"),
            actions: [
              // Profil Blade : soi-même ou admin.
              if (access.canEditUser(userId))
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserEditPage(userId: userId),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: FutureBuilder<User>(
            future: UserService().getUserById(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Erreur: ${snapshot.error}"));
              } else if (snapshot.hasData) {
                final user = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nom: ${user.name}",
                        style: const TextStyle(fontSize: 20),
                      ),
                      Text("Email: ${user.email}"),
                      Text("Tél: ${user.tel ?? '-'}"),
                      Text("Fonction: ${user.fonction ?? '-'}"),
                      Text("Rôle: ${user.userRole?.role?.libele ?? '-'}"),
                    ],
                  ),
                );
              }
              return const Center(child: Text("Aucun utilisateur trouvé"));
            },
          ),
        );
      },
    );
  }
}
