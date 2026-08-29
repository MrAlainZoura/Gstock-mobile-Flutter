import 'package:flutter/material.dart';

import '../../api/transfert_service.dart';
import '../../models/depot.dart';
import '../../models/transfert.dart';
import '../../utils/app_theme.dart';
import '../../utils/duree.dart';

/// Détail `GET /transferts/{id}`.
class TransfertShowPage extends StatefulWidget {
  const TransfertShowPage({
    super.key,
    required this.transfertId,
    this.depot,
  });

  final int transfertId;
  final Depot? depot;

  @override
  State<TransfertShowPage> createState() => _TransfertShowPageState();
}

class _TransfertShowPageState extends State<TransfertShowPage> {
  bool _loading = true;
  String? _error;
  Transfert? _transfert;

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
      final item = await TransfertService().getById(widget.transfertId);
      if (!mounted) return;
      setState(() {
        _transfert = item;
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

  @override
  Widget build(BuildContext context) {
    final t = _transfert;
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text(
          t == null
              ? 'Détail transfert'
              : (t.code.isEmpty ? 'Transfert #${t.id}' : t.code),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : t == null
                  ? const Center(child: Text('Transfert introuvable'))
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
                                  _kv('Code', t.code),
                                  _kv('Destination', t.destination),
                                  _kv('Initiateur', t.initiateur),
                                  _kv(
                                    'Statut',
                                    t.isConfirmed
                                        ? 'Réception confirmée'
                                        : 'En attente de réception',
                                  ),
                                  if ((t.description ?? '').trim().isNotEmpty)
                                    _kv('Description', t.description!.trim()),
                                  if (t.createdAt != null)
                                    _kv(
                                      'Date',
                                      formatDateTimeFr(t.createdAt),
                                    ),
                                  _kv('Total qté', '${t.totalQuantite}'),
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
                                    'Produits transférés',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (t.lignes.isEmpty)
                                    const Text(
                                      'Aucun produit',
                                      style: TextStyle(color: AppColors.gray),
                                    )
                                  else
                                    ...t.lignes.map(
                                      (l) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                l.libele,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'x ${l.quantite}',
                                              style: const TextStyle(
                                                color: AppColors.gray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
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
            width: 120,
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
