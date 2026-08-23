import 'package:flutter/material.dart';

import '../../api/compassassion_service.dart';
import '../../models/depot.dart';
import '../../models/vente.dart';
import '../../utils/app_theme.dart';
import '../../utils/period.dart';
import 'show.dart';

/// Liste `GET /compassassions/depot/{depot}` — défaut : mois en cours.
class CompassassionIndexPage extends StatefulWidget {
  const CompassassionIndexPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<CompassassionIndexPage> createState() => _CompassassionIndexPageState();
}

class _CompassassionIndexPageState extends State<CompassassionIndexPage> {
  PeriodRange _period = PeriodRange.month();
  final _search = TextEditingController();
  String _query = '';
  List<Vente> _items = [];
  bool _loading = true;
  String? _error;

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
      final all = await CompassassionService().listByDepot(widget.depot.id);
      final filtered = all.where((v) {
        final date = _compassDate(v) ?? v.createdAt;
        return date == null || _period.contains(date);
      }).toList();
      if (!mounted) return;
      setState(() {
        _items = filtered;
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

  /// Date de la compassassion (dernier article échangé), sinon date vente.
  DateTime? _compassDate(Vente v) {
    DateTime? latest;
    for (final raw in v.compassassion ?? const []) {
      if (raw is! Map) continue;
      final d = DateTime.tryParse(raw['created_at']?.toString() ?? '');
      if (d == null) continue;
      if (latest == null || d.isAfter(latest)) latest = d;
    }
    return latest;
  }

  List<Vente> get _rows {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((v) => v.searchText.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text('Compassassions — ${widget.depot.libele}'),
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
                    hintText: 'Rechercher (code, client, produit…)',
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
                  '${rows.length} compassassion(s)',
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
                    ? Center(child: Text('Erreur: $_error'))
                    : rows.isEmpty
                        ? const Center(child: Text('Aucune compassassion'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final vente = rows[index];
                                final date =
                                    _compassDate(vente) ?? vente.createdAt;
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      vente.code.isEmpty
                                          ? 'Vente #${vente.id}'
                                          : vente.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        [
                                          'Nouveau: ${vente.productSummary}',
                                          if (vente.lignes.isNotEmpty)
                                            'Avant: ${vente.lignes.first.libele}'
                                                '${vente.lignes.length > 1 ? ' ...' : ''}',
                                          if (vente.clientName.isNotEmpty)
                                            vente.clientName,
                                          date?.toString().split('.').first ??
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
    );
  }
}
