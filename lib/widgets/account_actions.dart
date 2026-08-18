import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../pages/user/user_index.dart';
import '../pages/user/user_show.dart';
import '../utils/access.dart';

/// Menu profil (haut) : profil / utilisateurs + déconnexion.
List<Widget> accountAppBarActions(
  BuildContext context,
  Access access, {
  int? depotId,
}) {
  return [
    PopupMenuButton<String>(
      tooltip: 'Profil',
      icon: const Icon(Icons.person),
      onSelected: (value) async {
        if (value == 'users') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserListScreen(depotId: depotId),
            ),
          );
        } else if (value == 'profile' && access.user != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDetailScreen(userId: access.user!.id),
            ),
          );
        } else if (value == 'logout') {
          await AuthService().logout();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          }
        }
      },
      itemBuilder: (context) => [
        if (access.isAdmin)
          const PopupMenuItem(
            value: 'users',
            child: _MenuRow(icon: Icons.people, label: 'Utilisateurs'),
          ),
        if (access.user != null)
          const PopupMenuItem(
            value: 'profile',
            child: _MenuRow(icon: Icons.person_outline, label: 'Mon profil'),
          ),
        const PopupMenuItem(
          value: 'logout',
          child: _MenuRow(icon: Icons.logout, label: 'Déconnexion'),
        ),
      ],
    ),
  ];
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
