import 'package:flutter/material.dart';

import '../user_form.dart';

/// Alias de mise à jour : `PUT /users/{id}` (voir [UserFormScreen]).
class UserEditPage extends StatelessWidget {
  const UserEditPage({super.key, required this.userId, this.depotId});

  final int userId;
  final int? depotId;

  @override
  Widget build(BuildContext context) {
    return UserFormScreen(userId: userId, depotId: depotId);
  }
}
