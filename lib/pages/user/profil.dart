import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/approvisionnement_service.dart';
import '../../api/auth_service.dart';
import '../../api/reservation_service.dart';
import '../../api/user_service.dart';
import '../../api/vente_service.dart';
import '../../models/user.dart';
import '../../models/vente.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../utils/methode.dart';
import '../user_form.dart';

/// Profil utilisateur : infos, stats d'opérations, édition, mot de passe.
class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key, required this.userId, this.depotId});

  final int userId;
  final int? depotId;

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  bool _loading = true;
  String? _error;
  User? _user;
  Access _access = Access();
  _UserStats _stats = const _UserStats();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await Access.load();
      final user = await UserService().getUserById(widget.userId);
      final stats = await _loadStats(user.id, widget.depotId);
      if (!mounted) return;
      setState(() {
        _access = access;
        _user = user;
        _stats = stats;
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

  Future<_UserStats> _loadStats(int userId, int? depotId) async {
    if (depotId == null) return const _UserStats();
    var ventes = 0;
    var reservations = 0;
    var appros = 0;
    var compassassions = 0;
    try {
      final list = await VenteService().getByDepot(depotId);
      ventes = list.where((v) => v.userId == userId).length;
      compassassions = list
          .where((v) => v.userId == userId && v.hasCompassassion)
          .length;
    } catch (_) {}
    try {
      final list = await ReservationService().getByDepot(depotId);
      reservations = list.where((r) => r.userId == userId).length;
    } catch (_) {}
    try {
      final data = await ApprovisionnementService().listByDepot(depotId);
      final raw = asList(data['approvisionnements']);
      appros = raw.whereType<Map>().where((e) {
        return asInt(e['user_id']) == userId;
      }).length;
    } catch (_) {}
    return _UserStats(
      ventes: ventes,
      reservations: reservations,
      approvisionnements: appros,
      compassassions: compassassions,
    );
  }

  Future<void> _edit() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UserFormScreen(userId: widget.userId),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  Future<void> _showPasswordModal() async {
    final user = _user;
    if (user == null) return;
    final holdCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Changer le mot de passe'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: holdCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe actuel',
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: newCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe (min. 4)',
                      ),
                      validator: (v) =>
                          v == null || v.length < 4 ? 'Trop court' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                      ),
                      validator: (v) =>
                          v != newCtrl.text ? 'Ne correspond pas' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setLocal(() => saving = true);
                          try {
                            await AuthService().updatePassword(
                              userId: user.id,
                              holdPass: holdCtrl.text,
                              password: newCtrl.text,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mot de passe mis à jour'),
                              ),
                            );
                          } on ApiException catch (e) {
                            setLocal(() => saving = false);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.red,
                                content: Text(e.message),
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
    holdCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final canEdit = _access.canEditUser(widget.userId);
    final fullName = user == null
        ? ''
        : [user.name, user.postnom, user.prenom]
            .where((e) => e != null && e.trim().isNotEmpty)
            .join(' ');

    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          if (canEdit) ...[
            IconButton(
              tooltip: 'Mot de passe',
              onPressed: _showPasswordModal,
              icon: const Icon(Icons.lock_outline),
            ),
            IconButton(
              tooltip: 'Modifier',
              onPressed: _edit,
              icon: const Icon(Icons.edit),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : user == null
                  ? const Center(child: Text('Utilisateur introuvable'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName.isEmpty ? user.name : fullName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.userRole?.role?.libele ?? 'user',
                                    style: const TextStyle(color: AppColors.gray),
                                  ),
                                  const Divider(height: 24),
                                  _kv('Email', user.email),
                                  _kv('Téléphone', user.tel ?? '—'),
                                  _kv('Fonction', user.fonction ?? '—'),
                                  _kv('Genre', user.genre ?? '—'),
                                  _kv('Naissance', user.naissance ?? '—'),
                                  _kv('Adresse', user.adresse ?? '—'),
                                  _kv('Niveau', user.niveauEtude ?? '—'),
                                  _kv('Option', user.option ?? '—'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Statistiques (dépôt courant)',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Opérations réalisées sur la plateforme',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.gray,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatTile(
                                          label: 'Ventes',
                                          value: _stats.ventes,
                                          color: AppColors.blue,
                                        ),
                                      ),
                                      Expanded(
                                        child: _StatTile(
                                          label: 'Réserv.',
                                          value: _stats.reservations,
                                          color: AppColors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _StatTile(
                                          label: 'Appro.',
                                          value: _stats.approvisionnements,
                                          color: AppColors.black,
                                        ),
                                      ),
                                      Expanded(
                                        child: _StatTile(
                                          label: 'Compass.',
                                          value: _stats.compassassions,
                                          color: AppColors.gray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (canEdit) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _showPasswordModal,
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Changer le mot de passe'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _edit,
                              icon: const Icon(Icons.edit),
                              label: const Text('Mettre à jour mes infos'),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AppColors.gray)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserStats {
  const _UserStats({
    this.ventes = 0,
    this.reservations = 0,
    this.approvisionnements = 0,
    this.compassassions = 0,
  });

  final int ventes;
  final int reservations;
  final int approvisionnements;
  final int compassassions;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.gray)),
        ],
      ),
    );
  }
}
