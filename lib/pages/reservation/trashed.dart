import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/reservation_service.dart';
import '../../models/depot.dart';
import '../../models/reservation.dart';
import '../../utils/app_theme.dart';
import '../../utils/duree.dart';
import '../../utils/period.dart';
import '../../widgets/confirm_dialog.dart';

/// Corbeille réservations — soft-delete. Par défaut : suppressions du mois.
class ReservationTrashedPage extends StatefulWidget {
  const ReservationTrashedPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<ReservationTrashedPage> createState() => _ReservationTrashedPageState();
}

class _ReservationTrashedPageState extends State<ReservationTrashedPage> {
  PeriodRange _period = PeriodRange.month();
  final _search = TextEditingController();
  String _query = '';
  List<Reservation> _reservations = [];
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
      final all = await ReservationService().getTrashed(
        widget.depot.id,
        from: _period.from,
        to: _period.to,
      );
      final filtered = all
          .where((r) => r.deletedAt == null || _period.contains(r.deletedAt))
          .toList();
      if (!mounted) return;
      setState(() {
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

  Future<void> _restore(Reservation row) async {
    final ok = await confirmAction(
      context,
      title: 'Restaurer cette réservation ?',
      message: 'La réservation ${row.code.isEmpty ? '#${row.id}' : row.code} '
          'quittera la corbeille.',
      confirmLabel: 'Restaurer',
      destructive: false,
    );
    if (!ok || !mounted) return;
    try {
      await ReservationService().restore(row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation restaurée')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _forceDelete(Reservation row) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer définitivement ?',
      message:
          'Cette réservation sera effacée sans possibilité de restauration.',
    );
    if (!ok || !mounted) return;
    try {
      await ReservationService().forceDelete(row.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation supprimée définitivement')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(
        title: Text("Corbeille réserv. — ${widget.depot.libele}"),
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
                  "${rows.length} suppression(s)",
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
                            child: Text("Aucune réservation supprimée"),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      8,
                                      8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.code.isEmpty
                                              ? "Réservation #${row.id}"
                                              : row.code,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            row.productSummary,
                                            if (row.clientName.isNotEmpty)
                                              row.clientName,
                                            if (row.periode != '—')
                                              row.periode,
                                            'Supprimée ${formatDateTimeFr(row.deletedAt)}',
                                          ].join(' · '),
                                          style: const TextStyle(
                                            color: AppColors.gray,
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _restore(row),
                                              icon: const Icon(Icons.restore),
                                              label: const Text('Restaurer'),
                                            ),
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: AppColors.red,
                                              ),
                                              onPressed: () =>
                                                  _forceDelete(row),
                                              icon: const Icon(
                                                Icons.delete_forever,
                                              ),
                                              label: const Text('Définitif'),
                                            ),
                                          ],
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
    );
  }
}
