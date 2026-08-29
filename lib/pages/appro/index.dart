import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/approvisionnement_service.dart';
import '../../api/auth_service.dart';
import '../../api/depot_catalog.dart';
import '../../models/depot.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../utils/methode.dart';
import '../../utils/period.dart';
import 'create.dart';
import '../transfert/index.dart';

/// Liste `GET /approvisionnements/depot/{depot}` — défaut : mois en cours.
class ApproIndexPage extends StatefulWidget {
  const ApproIndexPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<ApproIndexPage> createState() => _ApproIndexPageState();
}

class _ApproIndexPageState extends State<ApproIndexPage> {
  PeriodRange _period = PeriodRange.month();
  final _search = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;
  List<Approvisionnement> _all = [];
  Access _access = Access();

  @override
  void initState() {
    super.initState();
    if (!widget.depot.abonnementCurrent) {
      _period = PeriodRange.month();
    }
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
      final results = await Future.wait([
        ApprovisionnementService().listByDepot(widget.depot.id),
        Access.load(),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final access = results[1] as Access;
      final raw = asList(data['approvisionnements']);
      final items = raw
          .whereType<Map>()
          .map((e) => Approvisionnement.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _all = items;
        _access = access;
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

  List<Approvisionnement> get _rows {
    final byPeriod = _all.where((item) {
      return item.createdAt == null || _period.contains(item.createdAt);
    });
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return byPeriod.toList();
    return byPeriod.where((item) {
      final hay = [
        item.produitLibele ?? '',
        item.userName ?? '',
        '${item.quantite}',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _confirm(Approvisionnement item) async {
    try {
      await ApprovisionnementService().confirm(item.id, 'one');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approvisionnement confirmé')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.red, content: Text(e.message)),
      );
    }
  }

  Future<void> _delete(Approvisionnement item) async {
    if (!_access.canDeleteAppro) return;
    try {
      await ApprovisionnementService().delete(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approvisionnement supprimé')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.red, content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text('Approvisionnements — ${widget.depot.libele}'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            color: AppColors.black,
            surfaceTintColor: AppColors.black,
            onSelected: (value) async {
              if (value == 'transferts') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransfertIndexPage(depot: widget.depot),
                  ),
                );
                if (mounted) _load();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'transferts',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20, color: AppColors.white),
                    SizedBox(width: 12),
                    Text('Transferts', style: TextStyle(color: AppColors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PeriodFilterBar(
                  value: _period,
                  lockedToMonth: _access.getPeriodLockedToMonth(widget.depot),
                  onChanged: (range) {
                    setState(() => _period = range);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher (produit, utilisateur…)',
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
                const SizedBox(height: 6),
                Text(
                  '${rows.length} approvisionnement(s)',
                  style: const TextStyle(
                    color: AppColors.gray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: rows.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  Center(
                                    child: Text(
                                      'Aucun approvisionnement',
                                      style: TextStyle(color: AppColors.gray),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 96),
                                itemCount: rows.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final item = rows[i];
                                  final canConfirm =
                                      _access.canConfirmAllAppro ||
                                          (_access.canConfirmOwnAppro &&
                                              _access.user?.id != item.userId);
                                  return Card(
                                    child: ListTile(
                                      title: Text(
                                        item.produitLibele ?? 'Produit',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        [
                                          'Qté ${item.quantite}'
                                              '${item.unite != null && item.unite!.isNotEmpty ? ' ${item.unite}' : ''}',
                                          if (item.userName != null)
                                            item.userName!,
                                          if (item.createdAt != null)
                                            item.createdAt
                                                .toString()
                                                .split('.')
                                                .first,
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: AppColors.gray,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (canConfirm &&
                                              item.confirmed != true)
                                            IconButton(
                                              tooltip: 'Confirmer',
                                              onPressed: () => _confirm(item),
                                              icon: const Icon(
                                                Icons.check_circle_outline,
                                                color: AppColors.blue,
                                              ),
                                            ),
                                          if (_access.canDeleteAppro)
                                            IconButton(
                                              tooltip: 'Supprimer',
                                              onPressed: () => _delete(item),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: AppColors.red,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _access.canWrite(widget.depot)
          ? FloatingActionButton(
              onPressed: () async {
                final user = await AuthService().user();
                if (!context.mounted) return;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session utilisateur introuvable'),
                    ),
                  );
                  return;
                }
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ApproCreatePage(
                      depot: widget.depot,
                      userId: user.id,
                    ),
                  ),
                );
                if (ok == true && mounted) {
                  unawaited(
                    DepotCatalogStore.refreshInBackground(widget.depot.id),
                  );
                  await _load();
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
