import 'package:flutter/material.dart';

import '../../api/client_service.dart';
import '../../models/client.dart';
import '../../models/depot.dart';
import '../../utils/app_theme.dart';
import 'edit.dart';

enum _ClientPeriod { year, month }

/// Clients fidèles (≥2 ventes ou réservations) — filtre + cards.
class ClientIndexPage extends StatefulWidget {
  const ClientIndexPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<ClientIndexPage> createState() => _ClientIndexPageState();
}

class _ClientIndexPageState extends State<ClientIndexPage> {
  _ClientPeriod _period = _ClientPeriod.year;
  List<Client> _clients = [];
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
      final list = _period == _ClientPeriod.month
          ? await ClientService().getMensuel(widget.depot.id)
          : await ClientService().getAnnuel(widget.depot.id);
      if (!mounted) return;
      setState(() {
        _clients = list;
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

  List<Client> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _clients;
    return _clients.where((c) => c.searchText.contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final year = DateTime.now().year;
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text('Clients — ${widget.depot.libele}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Année $year'),
                      selected: _period == _ClientPeriod.year,
                      onSelected: (_) {
                        setState(() => _period = _ClientPeriod.year);
                        _load();
                      },
                      selectedColor: AppColors.blue,
                      labelStyle: TextStyle(
                        color: _period == _ClientPeriod.year
                            ? AppColors.white
                            : AppColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('Mois en cours'),
                      selected: _period == _ClientPeriod.month,
                      onSelected: (_) {
                        setState(() => _period = _ClientPeriod.month);
                        _load();
                      },
                      selectedColor: AppColors.blue,
                      labelStyle: TextStyle(
                        color: _period == _ClientPeriod.month
                            ? AppColors.white
                            : AppColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Filtrer (nom, tél, pièce…)',
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
                  '${rows.length} client(s) · ≥ 2 ventes ou réservations',
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
                    : rows.isEmpty
                        ? const Center(child: Text('Aucun client fidèle'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: rows.length,
                              itemBuilder: (context, i) {
                                final c = rows[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: AppColors.blue,
                                      child: Icon(
                                        Icons.person,
                                        color: AppColors.white,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      c.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (c.tel != null &&
                                            c.tel!.trim().isNotEmpty)
                                          c.tel!,
                                        '${c.ventesCount ?? 0} vente(s)',
                                        '${c.reservationsCount ?? 0} réserv.',
                                      ].join(' · '),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () async {
                                      final ok = await Navigator.push<bool>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ClientEditPage(
                                            depot: widget.depot,
                                            clientId: c.id,
                                          ),
                                        ),
                                      );
                                      if (ok == true && mounted) await _load();
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
