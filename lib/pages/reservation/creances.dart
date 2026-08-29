import 'package:flutter/material.dart';

import '../../api/reservation_service.dart';
import '../../models/depot.dart';
import '../../models/reservation.dart';
import '../../utils/app_theme.dart';
import '../../utils/duree.dart';
import '../../utils/period.dart';
import 'show.dart';

/// Liste `GET /reservations/depot/{depot}/creance` — réservations par tranche.
class ReservationCreancesPage extends StatefulWidget {
  const ReservationCreancesPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<ReservationCreancesPage> createState() =>
      _ReservationCreancesPageState();
}

class _ReservationCreancesPageState extends State<ReservationCreancesPage> {
  PeriodRange _period = PeriodRange.month();
  final _search = TextEditingController();
  String _query = '';
  List<ReservationCreance> _items = [];
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
      final all = await ReservationService().getCreances(
        widget.depot.id,
        from: _period.from,
        to: _period.to,
      );
      final filtered = all
          .where((e) => e.date == null || _period.contains(e.date))
          .toList();
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

  List<ReservationCreance> get _rows {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((e) => e.searchText.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(
        title: Text("Réservations par tranche — ${widget.depot.libele}"),
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
                  lockedToMonth: !widget.depot.abonnementCurrent,
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
                    hintText: "Rechercher (client, produit, vendeur…)",
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
                  "${rows.length} réservation(s) par tranche",
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
                        ? const Center(
                            child: Text("Aucune réservation par tranche"),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = rows[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      item.clientNom.isEmpty
                                          ? "Réservation #${item.id}"
                                          : item.clientNom,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        [
                                          item.productSummary,
                                          if (item.vendeur.isNotEmpty)
                                            item.vendeur,
                                          'Avance / reste ${item.lastTranche}',
                                          if (item.date != null)
                                            formatDateTimeFr(item.date),
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
                                          builder: (_) => ReservationShowPage(
                                            reservationId: item.id,
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
