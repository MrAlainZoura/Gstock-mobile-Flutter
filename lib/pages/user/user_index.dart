import 'package:flutter/material.dart';

import '../../api/user_service.dart';
import '../../models/user.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../user_form.dart';
import 'user_show.dart';

/// Liste utilisateurs du PDV — filtre + liste (comme dashboard).
class UserListScreen extends StatefulWidget {
  const UserListScreen({
    super.key,
    this.depotId,
    this.abonnementCurrent = true,
  });

  final int? depotId;
  final bool abonnementCurrent;

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  Access _access = Access();
  List<User> _users = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await Access.load();
      List<User> users = [];
      if (access.isAdmin && widget.depotId != null) {
        users = await UserService().getUsersByDepot(widget.depotId!);
      }
      if (!mounted) return;
      setState(() {
        _access = access;
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<User> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      final hay = [
        u.name,
        u.postnom,
        u.prenom,
        u.email,
        u.tel,
        u.fonction,
        u.userRole?.role?.libele,
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _openForm({User? user}) async {
    final canWrite = _access.isSuperAdmin || widget.abonnementCurrent;
    if (user == null && !canWrite) {
      _access.showSubscriptionBlocked(context);
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UserFormScreen(
          userId: user?.id,
          depotId: widget.depotId,
        ),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = _access.isSuperAdmin || widget.abonnementCurrent;
    final rows = _filtered;

    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(title: const Text('Utilisateurs du point de vente')),
      body: !_access.isAdmin && !_loading
          ? const Center(child: Text('Accès réservé aux administrateurs'))
          : widget.depotId == null
              ? const Center(
                  child: Text(
                    'Sélectionnez un point de vente pour voir ses utilisateurs',
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Filtrer (nom, email, rôle, tél…)',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${rows.length} utilisateur(s)',
                          style: const TextStyle(
                            color: AppColors.gray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(child: Text(_error!))
                              : rows.isEmpty
                                  ? const Center(
                                      child: Text('Aucun utilisateur'),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: _load,
                                      child: ListView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          16,
                                          88,
                                        ),
                                        itemCount: rows.length,
                                        itemBuilder: (context, i) {
                                          final u = rows[i];
                                          final deleted = u.isDeleted;
                                          return Card(
                                            margin: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: deleted
                                                    ? AppColors.gray
                                                    : AppColors.black,
                                                child: Icon(
                                                  deleted
                                                      ? Icons.person_off
                                                      : Icons.person,
                                                  color: AppColors.white,
                                                  size: 18,
                                                ),
                                              ),
                                              title: Text(
                                                u.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  decoration: deleted
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                ),
                                              ),
                                              subtitle: Text(
                                                deleted
                                                    ? '${u.email} · Supprimé'
                                                    : u.email,
                                              ),
                                              trailing: const Icon(
                                                Icons.chevron_right,
                                              ),
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        UserDetailScreen(
                                                      userId: u.id,
                                                      depotId: widget.depotId,
                                                    ),
                                                  ),
                                                ).then((_) => _load());
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                    ),
                  ],
                ),
      floatingActionButton: _access.canCreateUser
          ? FloatingActionButton(
              onPressed: () => _openForm(),
              backgroundColor: canWrite ? null : AppColors.gray,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
