import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/transfert_service.dart';
import '../../models/depot.dart';
import '../../models/transfert.dart';
import '../../utils/app_theme.dart';
import '../../utils/methode.dart';

/// Création `POST /transferts` — dépôts du même admin sauf dépôt courant.
class TransfertCreatePage extends StatefulWidget {
  const TransfertCreatePage({super.key, required this.depot});

  final Depot depot;

  @override
  State<TransfertCreatePage> createState() => _TransfertCreatePageState();
}

class _TransfertCreatePageState extends State<TransfertCreatePage> {
  final _search = TextEditingController();
  final _description = TextEditingController();
  String _query = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<TransfertStockItem> _stock = [];
  List<TransfertDepotOption> _depots = [];
  TransfertDepotOption? _destination;
  final List<_Line> _lines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _description.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await TransfertService().getCreateForm(widget.depot.id);
      final stock = asList(data['produits'])
          .whereType<Map>()
          .map((e) => TransfertStockItem.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.produitId > 0 && p.quantite > 0)
          .toList()
        ..sort((a, b) => a.libele.toLowerCase().compareTo(b.libele.toLowerCase()));
      final depots = asList(data['depotList'] ?? data['depot_list'])
          .whereType<Map>()
          .map((e) => TransfertDepotOption.fromJson(Map<String, dynamic>.from(e)))
          .where((d) => d.id > 0 && d.id != widget.depot.id)
          .toList();
      if (!mounted) return;
      setState(() {
        _stock = stock;
        _depots = depots;
        _destination = depots.isEmpty ? null : depots.first;
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

  List<TransfertStockItem> get _available {
    final selected = _lines.map((l) => l.item.produitId).toSet();
    final q = _query.trim().toLowerCase();
    return _stock.where((p) {
      if (selected.contains(p.produitId)) return false;
      if (q.isEmpty) return true;
      return p.libele.toLowerCase().contains(q);
    }).toList();
  }

  void _add(TransfertStockItem item) {
    setState(() {
      _lines.add(_Line(item: item));
      _search.clear();
      _query = '';
    });
  }

  Future<void> _submit() async {
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un point de vente destination')),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un produit')),
      );
      return;
    }
    final produits = <String, int>{};
    for (final line in _lines) {
      final qty = int.tryParse(line.qty.text.trim()) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quantité invalide pour ${line.item.libele}')),
        );
        return;
      }
      if (qty >= line.item.quantite) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Quantité trop élevée pour ${line.item.libele} (stock ${line.item.quantite})',
            ),
          ),
        );
        return;
      }
      produits['${line.item.produitId}'] = qty;
    }

    setState(() => _saving = true);
    try {
      final created = await TransfertService().create(
        depotId: widget.depot.id,
        destinationId: _destination!.id,
        produits: produits,
        description: _description.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transfert ${created.code} enregistré')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.red, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text('Nouveau transfert — ${widget.depot.libele}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destination',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_depots.isEmpty)
                              const Text(
                                'Aucun autre point de vente du même administrateur',
                                style: TextStyle(color: AppColors.gray),
                              )
                            else
                              DropdownButtonFormField<TransfertDepotOption>(
                                initialValue: _destination,
                                decoration: const InputDecoration(
                                  labelText: 'Point de vente destination',
                                ),
                                items: _depots
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _destination = v),
                              ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _description,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Description (optionnel)',
                              ),
                            ),
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
                              'Produits',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _search,
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                hintText: 'Rechercher un produit',
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
                            const SizedBox(height: 8),
                            if (_query.trim().isEmpty)
                              const Text(
                                'Tapez pour rechercher un produit à transférer',
                                style: TextStyle(color: AppColors.gray),
                              )
                            else if (_available.isEmpty)
                              const Text(
                                'Aucun produit trouvé',
                                style: TextStyle(color: AppColors.gray),
                              )
                            else
                              ..._available.take(5).map(
                                    (p) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.add_circle_outline,
                                        color: AppColors.blue,
                                      ),
                                      title: Text(p.libele),
                                      subtitle: Text(
                                        'Stock ${p.quantite} ${p.unite}',
                                        style: const TextStyle(
                                          color: AppColors.gray,
                                        ),
                                      ),
                                      onTap: _saving ? null : () => _add(p),
                                    ),
                                  ),
                            const Divider(height: 24),
                            if (_lines.isEmpty)
                              const Text(
                                'Aucun produit sélectionné',
                                style: TextStyle(color: AppColors.gray),
                              )
                            else
                              ..._lines.map((line) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line.item.libele,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'Stock ${line.item.quantite} ${line.item.unite}',
                                              style: const TextStyle(
                                                color: AppColors.gray,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 88,
                                        child: TextField(
                                          controller: line.qty,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Qté',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _saving
                                            ? null
                                            : () {
                                                setState(() {
                                                  line.dispose();
                                                  _lines.remove(line);
                                                });
                                              },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: AppColors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saving || _depots.isEmpty ? null : _submit,
                      child: Text(
                        _saving ? 'Enregistrement…' : 'Transférer',
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Line {
  _Line({required this.item}) : qty = TextEditingController(text: '1');

  final TransfertStockItem item;
  final TextEditingController qty;

  void dispose() => qty.dispose();
}
