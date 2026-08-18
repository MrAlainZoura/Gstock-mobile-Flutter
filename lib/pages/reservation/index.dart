import 'package:flutter/material.dart';

import '../../api/reservation_service.dart';
import '../../models/depot.dart';
import '../../models/reservation.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../utils/duree.dart';
import '../../utils/period.dart';
import 'show.dart';
import 'trashed.dart';

/// Liste `GET /reservations/depot/{depot}` — par défaut les réservations du jour.
class ReservationIndexPage extends StatefulWidget {
  const ReservationIndexPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<ReservationIndexPage> createState() => _ReservationIndexPageState();
}

class _ReservationIndexPageState extends State<ReservationIndexPage> {
  PeriodRange _period = PeriodRange.today();
  final _search = TextEditingController();
  String _query = '';
  List<Reservation> _reservations = [];
  bool _loading = true;
  String? _error;
  Access _access = Access();

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
      final all = await ReservationService().getByDepot(
        widget.depot.id,
        from: _period.from,
        to: _period.to,
      );
      final filtered = all
          .where((r) => r.createdAt == null || _period.contains(r.createdAt))
          .toList();
      if (!mounted) return;
      setState(() {
        _access = access;
        _reservations = filtered;
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

  List<Reservation> get _rows {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _reservations;
    return _reservations.where((r) => r.searchText.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(
        title: Text("Réservations — ${widget.depot.libele}"),
        actions: [
          if (_access.canSeeCorbeille)
            IconButton(
              tooltip: 'Corbeille',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReservationTrashedPage(depot: widget.depot),
                  ),
                );
                if (mounted) _load();
              },
              icon: const Icon(Icons.delete_outline),
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
                  "${rows.length} réservation(s)",
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
                        ? const Center(child: Text("Aucune réservation"))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      row.code.isEmpty
                                          ? "Réservation #${row.id}"
                                          : row.code,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        [
                                          row.productSummary,
                                          if (row.clientName.isNotEmpty)
                                            row.clientName,
                                          if (row.periode != '—') row.periode,
                                          formatDateTimeFr(row.dateDebut),
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
                                            reservationId: row.id,
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
