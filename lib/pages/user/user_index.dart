import 'package:flutter/material.dart';

import '../../api/auth_service.dart';
import '../../api/user_service.dart';
import '../../utils/access.dart';
import '../user_form.dart';
import 'user_show.dart';

/// Liste utilisateurs — Blade `users/index` :
/// admin → affectés au dépôt ; `user` → soi-même uniquement.
class UserListScreen extends StatelessWidget {
  const UserListScreen({super.key, this.depotId});

  final int? depotId;

  Future<List<dynamic>> _load(Access access) async {
    if (depotId != null) {
      return UserService().getUsersByDepot(depotId!);
    }
    if (access.isAdmin) {
      return UserService().getAllUsers();
    }
    final me = access.user ?? await AuthService().user();
    return me == null ? [] : [me];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Access>(
      future: Access.load(),
      builder: (context, accessSnap) {
        if (!accessSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final access = accessSnap.data ?? Access();
        return Scaffold(
          appBar: AppBar(title: const Text("Liste des utilisateurs")),
          body: FutureBuilder(
            future: _load(access),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text("Erreur: ${snapshot.error}"));
              } else {
                final users = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      title: Text(user.name),
                      subtitle: Text(user.email),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailScreen(userId: user.id),
                          ),
                        );
                      },
                    );
                  },
                );
              }
            },
          ),
          // Sidebar Blade : « Ajouter » utilisateur = admin uniquement.
          floatingActionButton: access.canCreateUser
              ? FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserFormScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}
