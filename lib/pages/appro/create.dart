import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/approvisionnement_service.dart';
import '../../models/depot.dart';
import '../../models/produit.dart';
import '../../utils/app_theme.dart';
import '../../utils/methode.dart';

/// Création `POST /approvisionnements`.
class ApproCreatePage extends StatefulWidget {
  const ApproCreatePage({
    super.key,
    required this.depot,
    required this.userId,
    this.initialProduit,
    this.initialQty = 1,
  });

  final Depot depot;
  final int userId;
  /// Pré-sélection depuis la fiche produit.
  final Produit? initialProduit;
  final int initialQty;

  @override
  State<ApproCreatePage> createState() => _ApproCreatePageState();
}

class _ApproCreatePageState extends State<ApproCreatePage> {
  final _search = TextEditingController();
  String _query = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<_StockRow> _stock = [];
  final List<_ApproLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
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
      final data =
          await ApprovisionnementService().getCreateForm(widget.depot.id);
      final stock = asList(data['produits'])
          .whereType<Map>()
          .map((e) => _StockRow.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id > 0)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Pré-sélection depuis la fiche produit.
      final initial = widget.initialProduit;
      if (initial != null && initial.id > 0) {
        final match = stock.where((s) => s.id == initial.id);
        final row = match.isNotEmpty
            ? match.first
            : _StockRow(
                id: initial.id,
                name: [
                  if ((initial.marque ?? '').trim().isNotEmpty) initial.marque!,
                  initial.libele,
                ].where((e) => e.trim().isNotEmpty).join(' '),
                stock: initial.quantite ?? 0,
                unite: (initial.unite != null && initial.unite!.isNotEmpty)
                    ? initial.unite!
                    : 'pcs',
                search: initial.libele.toLowerCase(),
              );
        for (final line in _lines) {
          line.dispose();
        }
        _lines
          ..clear()
          ..add(_ApproLine(item: row, qty: widget.initialQty));
      }

      if (!mounted) return;
      setState(() {
        _stock = stock;
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

  List<_StockRow> get _available {
    final selected = _lines.map((l) => l.item.id).toSet();
    final q = _query.trim().toLowerCase();
    return _stock.where((p) {
      if (selected.contains(p.id)) return false;
      if (q.isEmpty) return true;
      return p.search.contains(q);
    }).toList();
  }

  void _add(_StockRow item) {
    setState(() {
      _lines.add(_ApproLine(item: item, qty: 1));
      _search.clear();
      _query = '';
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un produit')),
      );
      return;
    }
    for (final line in _lines) {
      if (line.qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quantité invalide pour ${line.item.name}')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final produits = <String, int>{
        for (final line in _lines) '${line.item.id}': line.qty,
      };
      await ApprovisionnementService().create(
        depotId: widget.depot.id,
        userId: widget.userId,
        produits: produits,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approvisionnement enregistré')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.red, content: Text(e.message)),
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
        title: Text('Nouvel appro — ${widget.depot.libele}'),
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
                                'Tapez pour rechercher un produit à approvisionner',
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
                                      title: Text(p.name),
                                      subtitle: Text(
                                        'Stock actuel ${p.stock} ${p.unite}',
                                        style: const TextStyle(
                                          color: AppColors.gray,
                                        ),
                                      ),
                                      onTap: () => _add(p),
                                    ),
                                  ),
                            if (_lines.isNotEmpty) ...[
                              const Divider(),
                              ..._lines.map(_lineCard),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text('Approvisionner'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _lineCard(_ApproLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.item.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 88,
            child: TextField(
              controller: line.qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qté'),
              onChanged: (v) => setState(() => line.qty = int.tryParse(v) ?? 0),
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _lines.remove(line);
              line.dispose();
            }),
            icon: const Icon(Icons.close, color: AppColors.red),
          ),
        ],
      ),
    );
  }
}

class _StockRow {
  _StockRow({
    required this.id,
    required this.name,
    required this.stock,
    required this.unite,
    required this.search,
  });

  final int id;
  final String name;
  final int stock;
  final String unite;
  final String search;

  factory _StockRow.fromJson(Map<String, dynamic> json) {
    final nested = asMap(json['produit']) ?? json;
    final produit = Produit.fromJson(nested);
    final marque = produit.marque?.trim() ?? '';
    final name = [
      if (marque.isNotEmpty) marque,
      produit.libele,
    ].where((e) => e.trim().isNotEmpty).join(' ');
    return _StockRow(
      id: produit.id > 0 ? produit.id : asInt(json['produit_id']),
      name: name.isEmpty ? 'Produit' : name,
      stock: asInt(json['quantite'] ?? json['quatité'] ?? produit.quantite),
      unite: (produit.unite != null && produit.unite!.isNotEmpty)
          ? produit.unite!
          : 'pcs',
      search: [
        name,
        produit.categorie ?? '',
        produit.description,
      ].join(' ').toLowerCase(),
    );
  }
}

class _ApproLine {
  _ApproLine({required this.item, required int qty})
      : qtyCtrl = TextEditingController(text: '$qty'),
        qty = qty;

  final _StockRow item;
  final TextEditingController qtyCtrl;
  int qty;

  void dispose() => qtyCtrl.dispose();
}
