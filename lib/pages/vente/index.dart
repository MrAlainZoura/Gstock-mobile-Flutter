import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/depot_catalog.dart';
import '../../api/vente_service.dart';
import '../../models/depot.dart';
import '../../models/vente.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../utils/period.dart';
import 'create.dart';
import 'compassassion_index.dart';
import 'creances.dart';
import 'show.dart';
import 'trashed.dart';

/// Liste `GET /ventes/depot/{depot}` — par défaut les ventes du jour.
class VenteIndexPage extends StatefulWidget {
  const VenteIndexPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<VenteIndexPage> createState() => _VenteIndexPageState();
}

class _VenteIndexPageState extends State<VenteIndexPage> {
  PeriodRange _period = PeriodRange.today();
  final _search = TextEditingController();
  String _query = '';
  List<Vente> _ventes = [];
  bool _loading = true;
  String? _error;
  Access _access = Access();

  @override
  void initState() {
    super.initState();
    if (!widget.depot.abonnementCurrent) {
      _period = PeriodRange.month();
    }
    _load();
    unawaited(DepotCatalogStore.refreshInBackground(widget.depot.id));
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
      final all = await VenteService().getByDepot(
        widget.depot.id,
        from: _period.from,
        to: _period.to,
      );
      final filtered = all
          .where((v) => v.createdAt == null || _period.contains(v.createdAt))
          .toList();
      if (!mounted) return;
      setState(() {
        _access = access;
        _ventes = filtered;
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

  List<Vente> get _rows {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _ventes;
    return _ventes.where((v) => v.searchText.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(
        title: Text("Ventes — ${widget.depot.libele}"),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            color: AppColors.black,
            surfaceTintColor: AppColors.black,
            onSelected: (value) async {
              if (value == 'compassassions') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CompassassionIndexPage(depot: widget.depot),
                  ),
                );
                if (mounted) _load();
              } else if (value == 'tranches') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VenteCreancesPage(depot: widget.depot),
                  ),
                );
                if (mounted) _load();
              } else if (value == 'corbeille') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VenteTrashedPage(depot: widget.depot),
                  ),
                );
                if (mounted) _load();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'compassassions',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 20, color: AppColors.white),
                    SizedBox(width: 12),
                    Text(
                      'Compassassions',
                      style: TextStyle(color: AppColors.white),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tranches',
                child: Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 20,
                      color: AppColors.white,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Ventes par tranche',
                      style: TextStyle(color: AppColors.white),
                    ),
                  ],
                ),
              ),
              if (_access.canSeeCorbeille)
                const PopupMenuItem(
                  value: 'corbeille',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.white,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Corbeille',
                        style: TextStyle(color: AppColors.white),
                      ),
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
                    _load();
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: "Rechercher (code, client, produit…)",
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
                  "${rows.length} vente(s)",
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
                    ? Center(child: Text("Erreur: $_error"))
                    : rows.isEmpty
                        ? const Center(child: Text("Aucune vente"))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final vente = rows[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      vente.code.isEmpty
                                          ? "Vente #${vente.id}"
                                          : vente.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        [
                                          if (vente.hasCompassassion)
                                            'Compassassion',
                                          vente.productSummary,
                                          if (vente.clientName.isNotEmpty)
                                            vente.clientName,
                                          vente.createdAt
                                                  ?.toString()
                                                  .split('.')
                                                  .first ??
                                              '',
                                        ].join(' · '),
                                      ),
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      color: AppColors.gray,
                                    ),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VenteShowPage(
                                            venteId: vente.id,
                                            depot: widget.depot,
                                          ),
                                        ),
                                      );
                                      if (mounted) _load();
                                    },
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VenteCreatePage(depot: widget.depot),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
