import 'package:flutter/material.dart';

import '../../api/transfert_service.dart';
import '../../models/depot.dart';
import '../../models/transfert.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../utils/duree.dart';
import '../../utils/period.dart';
import 'create.dart';
import 'show.dart';

/// Liste `GET /transferts/depot/{depot}` — filtre période (défaut : mois).
class TransfertIndexPage extends StatefulWidget {
  const TransfertIndexPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<TransfertIndexPage> createState() => _TransfertIndexPageState();
}

class _TransfertIndexPageState extends State<TransfertIndexPage> {
  PeriodRange _period = PeriodRange.month();
  final _search = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;
  List<Transfert> _all = [];
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
      final access = await Access.load();
      final items = await TransfertService().getByDepot(
        widget.depot.id,
        from: _period.from,
        to: _period.to,
      );
      if (!mounted) return;
      setState(() {
        _access = access;
        _all = items;
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

  List<Transfert> get _rows {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((t) => t.searchText.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text('Transferts — ${widget.depot.libele}'),
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
                    hintText: 'Rechercher (code, destination…)',
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
                  '${rows.length} transfert(s)',
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
                                      'Aucun transfert',
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
                                  return Card(
                                    child: ListTile(
                                      title: Text(
                                        item.code.isEmpty
                                            ? 'Transfert #${item.id}'
                                            : item.code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        [
                                          'Vers ${item.destination}',
                                          'Qté ${item.totalQuantite}',
                                          item.initiateur,
                                          if (item.createdAt != null)
                                            formatDateTimeFr(item.createdAt),
                                        ].join(' · '),
                                        style: const TextStyle(
                                          color: AppColors.gray,
                                        ),
                                      ),
                                      trailing: Icon(
                                        item.isConfirmed
                                            ? Icons.check_circle
                                            : Icons.schedule,
                                        color: item.isConfirmed
                                            ? AppColors.blue
                                            : AppColors.gray,
                                      ),
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TransfertShowPage(
                                              transfertId: item.id,
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
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransfertCreatePage(depot: widget.depot),
                  ),
                );
                if (ok == true && mounted) await _load();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
