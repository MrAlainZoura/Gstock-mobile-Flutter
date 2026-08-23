import 'package:flutter/material.dart';

import 'profil.dart';

/// Alias : détail utilisateur = écran profil.
class UserDetailScreen extends StatelessWidget {
  final int userId;
  final int? depotId;
  const UserDetailScreen({super.key, required this.userId, this.depotId});

  @override
  Widget build(BuildContext context) {
    return ProfilPage(userId: userId, depotId: depotId);
  }
}
