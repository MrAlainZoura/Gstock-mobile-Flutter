import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/compassassion_service.dart';
import '../../api/depot_catalog.dart';
import '../../api/vente_service.dart';
import '../../models/depot.dart';
import '../../models/produit.dart';
import '../../models/vente.dart';
import '../../utils/app_theme.dart';
import '../../utils/methode.dart';
import 'show.dart';

/// Échange produit d'une vente — `POST /compassassions`.
///
/// Remplace les articles de la vente. Si l’ancien produit était une pièce,
/// il est écarté de la vente (non repris comme article facturé).
class CompassassionCreatePage extends StatefulWidget {
  const CompassassionCreatePage({
    super.key,
    required this.venteId,
    this.depot,
  });

  final int venteId;
  final Depot? depot;

  @override
  State<CompassassionCreatePage> createState() =>
      _CompassassionCreatePageState();
}

class _CompassassionCreatePageState extends State<CompassassionCreatePage> {
  final _search = TextEditingController();
  String _query = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  Vente? _vente;
  num _paiementDeja = 0;
  String _devise = 'USD';
  bool _prixEnCdf = false;
  List<_StockItem> _stock = [];
  final List<_CompLine> _lines = [];

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
      // Formulaire create n'embarque pas toujours venteProduit → on charge
      // le détail vente pour afficher la relation venteProduit d'origine.
      final results = await Future.wait([
        CompassassionService().getCreateForm(widget.venteId),
        VenteService().getById(widget.venteId),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final venteDetail = results[1] as Vente;
      final venteMap = asMap(data['vente']);
      final venteFromForm =
          venteMap == null ? null : Vente.fromJson(venteMap);
      // Priorité au détail (venteProduit) ; conserve devise/taux du form si besoin.
      final vente = Vente(
        id: venteDetail.id,
        userId: venteDetail.userId,
        depotId: venteDetail.depotId,
        clientId: venteDetail.clientId,
        code: venteDetail.code,
        type: venteDetail.type,
        createdAt: venteDetail.createdAt,
        updatedAt: venteDetail.updatedAt,
        deviseId: venteDetail.deviseId,
        updateTaux: venteDetail.updateTaux,
        deletedAt: venteDetail.deletedAt,
        paiement: venteDetail.paiement ?? venteFromForm?.paiement,
        produitVente: venteDetail.produitVente,
        compassassion: venteDetail.compassassion,
        client: venteDetail.client ?? venteFromForm?.client,
        devise: venteDetail.devise ?? venteFromForm?.devise,
        user: venteDetail.user ?? venteFromForm?.user,
      );
      final stock = asList(data['produits'])
          .whereType<Map>()
          .map((e) => _StockItem.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.id > 0)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _vente = vente;
        _paiementDeja = asDouble(data['paiement']) ?? 0;
        _devise = data['devise']?.toString() ?? 'USD';
        _prixEnCdf = data['cdfPrime'] == true || data['cdfPrime'] == 1;
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

  num get _net => _lines.fold<num>(0, (s, l) => s + l.prixT);

  List<_StockItem> get _available {
    final selected = _lines.map((l) => l.item.id).toSet();
    final q = _query.trim().toLowerCase();
    return _stock.where((p) {
      if (selected.contains(p.id)) return false;
      if (q.isEmpty) return true;
      return p.search.contains(q);
    }).toList();
  }

  void _add(_StockItem item) {
    if (item.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text('${item.name} est en rupture de stock'),
        ),
      );
      return;
    }
    final defaultPu = item.prix > 0 ? item.prix : item.cdfPrix;
    setState(() {
      _lines.add(_CompLine(item: item, qty: 1, prixU: defaultPu));
      _search.clear();
      _query = '';
    });
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez le nouveau produit')),
      );
      return;
    }
    for (final line in _lines) {
      if (line.qty <= 0 || line.prixU <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Qté et PU requis pour ${line.item.name}')),
        );
        return;
      }
      if (line.qty > line.item.stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.red,
            content: Text('Stock insuffisant pour ${line.item.name}'),
          ),
        );
        return;
      }
    }
    if (_net < _paiementDeja) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(
            'Le nouveau total (${formatMoney(_net)}) doit être ≥ au paiement déjà encaissé (${formatMoney(_paiementDeja)} $_devise)',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final produits = <String, Map<String, num>>{
        for (final line in _lines) '${line.item.id}': {'${line.qty}': line.prixT},
      };
      final updated = await CompassassionService().create(
        venteId: widget.venteId,
        produits: produits,
      );
      final depotId = widget.depot?.id ?? updated.depotId;
      if (depotId > 0) {
        // ignore: discarded_futures
        DepotCatalogStore.refreshInBackground(depotId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compassassion enregistrée')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VenteShowPage(
            venteId: widget.venteId,
            depot: widget.depot,
          ),
        ),
      );
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
    final vente = _vente;
    final oldLines = vente?.lignes ?? const <VenteLigne>[];
    final pieces = oldLines.where((l) => l.isPiece).toList();

    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text(
          vente == null
              ? 'Compassassion'
              : 'Compassassion — ${vente.code.isEmpty ? '#${vente.id}' : vente.code}',
        ),
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
                              'Produit(s) vente initiale (venteProduit)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (oldLines.isEmpty)
                              const Text(
                                'Aucun produit venteProduit',
                                style: TextStyle(color: AppColors.gray),
                              )
                            else
                              ...oldLines.map(
                                (l) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '${l.libele} · ${formatMoney(l.quantite)} ${l.unite ?? 'pcs'}'
                                    '${l.isPiece ? ' (pièce — sera écartée)' : ''}',
                                    style: TextStyle(
                                      color: l.isPiece
                                          ? AppColors.red
                                          : AppColors.black,
                                    ),
                                  ),
                                ),
                              ),
                            if (pieces.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Les pièces remplacées sont écartées de la vente '
                                '(échange contre le nouveau produit).',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Déjà payé : ${formatMoney(_paiementDeja)} $_devise',
                              style: const TextStyle(fontWeight: FontWeight.w600),
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
                              'Nouveau produit (compassassion)',
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
                                hintText: 'Rechercher le produit de remplacement',
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
                                'Tapez pour rechercher un produit',
                                style: TextStyle(color: AppColors.gray),
                              )
                            else if (_available.isEmpty)
                              const Text(
                                'Aucun produit à ajouter',
                                style: TextStyle(color: AppColors.gray),
                              )
                            else
                              ..._available.take(4).map(
                                    (p) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.swap_horiz,
                                        color: p.stock <= 0
                                            ? AppColors.gray
                                            : AppColors.blue,
                                      ),
                                      title: Text(p.name),
                                      subtitle: Text(
                                        'Stock ${p.stock} ${p.unite}',
                                        style: TextStyle(
                                          color: p.stock <= 0
                                              ? AppColors.red
                                              : AppColors.gray,
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
                    const SizedBox(height: 12),
                    Card(
                      color: AppColors.black,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nouveau net',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${formatMoney(_net)} ${_prixEnCdf ? 'CDF' : _devise}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Minimum : ${formatMoney(_paiementDeja)} $_devise',
                              style: const TextStyle(
                                color: AppColors.gray,
                                fontSize: 12,
                              ),
                            ),
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
                            : const Text('Échanger le produit'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _lineCard(_CompLine line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: AppColors.grayLight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qté'),
                    onChanged: (v) =>
                        setState(() => line.qty = int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: line.prixCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'PU (${_prixEnCdf ? 'CDF' : _devise})',
                    ),
                    onChanged: (v) =>
                        setState(() => line.prixU = asDouble(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total ${formatMoney(line.prixT)} ${_prixEnCdf ? 'CDF' : _devise}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockItem {
  _StockItem({
    required this.id,
    required this.name,
    required this.stock,
    required this.unite,
    required this.prix,
    required this.cdfPrix,
    required this.search,
  });

  final int id;
  final String name;
  final int stock;
  final String unite;
  final num prix;
  final num cdfPrix;
  final String search;

  factory _StockItem.fromJson(Map<String, dynamic> json) {
    final nested = asMap(json['produit']) ?? json;
    final produit = Produit.fromJson(nested);
    final marque = produit.marque?.trim() ?? '';
    final name = [
      if (marque.isNotEmpty) marque,
      produit.libele,
    ].where((e) => e.trim().isNotEmpty).join(' ');
    return _StockItem(
      id: produit.id > 0 ? produit.id : asInt(json['produit_id']),
      name: name.isEmpty ? 'Produit' : name,
      stock: asInt(json['quantite'] ?? json['quatité'] ?? produit.quantite),
      unite: (produit.unite != null && produit.unite!.isNotEmpty)
          ? produit.unite!
          : 'pcs',
      prix: asDouble(produit.prix) ?? 0,
      cdfPrix: asDouble(json['cdf_prix']) ?? 0,
      search: [
        name,
        produit.categorie ?? '',
        produit.description,
      ].join(' ').toLowerCase(),
    );
  }
}

class _CompLine {
  _CompLine({required this.item, required int qty, required num prixU})
      : qtyCtrl = TextEditingController(text: '$qty'),
        prixCtrl = TextEditingController(text: _plain(prixU)),
        qty = qty,
        prixU = prixU;

  final _StockItem item;
  final TextEditingController qtyCtrl;
  final TextEditingController prixCtrl;
  int qty;
  num prixU;

  num get prixT => qty * prixU;

  void dispose() {
    qtyCtrl.dispose();
    prixCtrl.dispose();
  }
}

String _plain(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toString();
}
