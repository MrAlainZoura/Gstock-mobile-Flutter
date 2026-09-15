import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/depot_catalog.dart';
import '../../api/depot_ops_store.dart';
import '../../api/page_cache.dart';
import '../../api/vente_service.dart';
import '../../models/depot.dart';
import '../../models/produit.dart';
import '../../models/vente.dart';
import '../../utils/app_theme.dart';
import '../../utils/methode.dart';
import 'show.dart';

/// Création `POST /ventes`.
///
/// `produits` : `{ "<produit_id>": { "<quantite>": <prix_total> } }`
/// `monnaie` : `"<devise_id>-<libele>"`.
class VenteCreatePage extends StatefulWidget {
  const VenteCreatePage({super.key, required this.depot});

  final Depot depot;

  @override
  State<VenteCreatePage> createState() => _VenteCreatePageState();
}

class _VenteCreatePageState extends State<VenteCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nomClient = TextEditingController(text: 'Passant');
  final _contact = TextEditingController();
  final _adresse = TextEditingController();
  final _search = TextEditingController();
  final _taux = TextEditingController();
  final _trancheP = TextEditingController();

  String _lieu = 'Shop';
  String _query = '';
  bool _tranche = false;
  bool _prixEnCdf = false;
  bool _loadingForm = true;
  bool _saving = false;
  String? _error;

  List<_StockItem> _stock = [];
  List<_DeviseOption> _devises = [];
  _DeviseOption? _devise;
  final List<_SaleLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _prixEnCdf = widget.depot.useCdf;
    _loadForm();
  }

  @override
  void dispose() {
    _nomClient.dispose();
    _contact.dispose();
    _adresse.dispose();
    _search.dispose();
    _taux.dispose();
    _trancheP.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadForm() async {
    final cached = await DepotCatalogStore.read(widget.depot.id);
    if (!mounted) return;
    if (cached != null) {
      _applyPayload(cached);
      unawaited(_refreshForm());
      return;
    }
    setState(() {
      _loadingForm = true;
      _error = null;
    });
    try {
      final data = await DepotCatalogStore.fetchAndStore(widget.depot.id);
      if (!mounted) return;
      _applyPayload(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingForm = false;
      });
    }
  }

  Future<void> _refreshForm() async {
    try {
      final data = await DepotCatalogStore.fetchAndStore(widget.depot.id);
      if (!mounted) return;
      _applyPayload(data, keepUserEdits: true);
    } catch (_) {}
  }

  void _applyPayload(
    Map<String, dynamic> data, {
    bool keepUserEdits = false,
  }) {
    final depotMap = asMap(data['depot']);
    final devises = asList(data['devises']).isNotEmpty
        ? asList(data['devises'])
        : asList(depotMap?['devise'] ?? depotMap?['devises']);
    final options = devises
        .whereType<Map>()
        .map((e) => _DeviseOption.fromJson(Map<String, dynamic>.from(e)))
        .where((d) => d.id > 0 && d.libele.isNotEmpty)
        .toList();
    final stock = asList(data['produits'])
        .whereType<Map>()
        .map((e) => _StockItem.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.id > 0)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final useCdf = depotMap?['use_cdf'] == true ||
        depotMap?['use_cdf'] == 1 ||
        widget.depot.useCdf;
    final selected = options.isEmpty ? null : options.first;

    setState(() {
      _devises = options;
      _stock = stock;
      if (!keepUserEdits || _devise == null) {
        _devise = selected;
        _prixEnCdf = useCdf;
        _taux.text = selected == null ? '' : _plain(selected.taux);
      } else {
        final match = options.where((d) => d.id == _devise!.id);
        if (match.isNotEmpty) _devise = match.first;
      }
      _loadingForm = false;
      _error = null;
    });
  }

  int _availableStock(_StockItem item) {
    for (final p in _stock) {
      if (p.id == item.id) return p.stock;
    }
    return item.stock;
  }

  num get _tauxValue {
    final value = asDouble(_taux.text.trim()) ?? 0;
    return value <= 0 ? 1 : value;
  }

  num get _net {
    return _lines.fold<num>(0, (sum, line) => sum + line.prixT);
  }

  MoneyPair get _netPair {
    if (_prixEnCdf) {
      return MoneyPair(cdf: _net, devise: _net / _tauxValue);
    }
    return MoneyPair(cdf: _net * _tauxValue, devise: _net);
  }

  List<_StockItem> get _available {
    final selectedIds = _lines.map((l) => l.item.id).toSet();
    final q = _query.trim().toLowerCase();
    return _stock.where((p) {
      if (selectedIds.contains(p.id)) return false;
      if (q.isEmpty) return true;
      return p.search.contains(q);
    }).toList();
  }

  void _selectDevise(_DeviseOption? option) {
    setState(() {
      _devise = option;
      if (option != null) _taux.text = _plain(option.taux);
    });
  }

  void _addProduct(_StockItem item) {
    if (_availableStock(item) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(
            "${item.name} est en rupture de stock. La vente ne sera pas enregistrée.",
          ),
        ),
      );
      return;
    }
    final defaultPu = _prixEnCdf
        ? (item.cdfPrix > 0 ? item.cdfPrix : item.prix)
        : (item.prix > 0 ? item.prix : item.cdfPrix);
    setState(() {
      _lines.add(_SaleLine(item: item, qty: 1, prixU: defaultPu));
      _search.clear();
      _query = '';
    });
  }

  void _removeLine(_SaleLine line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sélectionnez au moins un produit")),
      );
      return;
    }
    if (_devise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Choisissez une devise")),
      );
      return;
    }
    for (final line in _lines) {
      if (line.qty <= 0 || line.prixU <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Qté et PU requis pour ${line.item.name}")),
        );
        return;
      }
      final stock = _availableStock(line.item);
      if (stock <= 0 || line.qty > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.red,
            content: Text(
              stock <= 0
                  ? "${line.item.name} est en rupture de stock. La vente ne sera pas enregistrée."
                  : "Stock insuffisant pour ${line.item.name} ($stock). La vente ne sera pas enregistrée.",
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final produits = <String, Map<String, num>>{};
      for (final line in _lines) {
        produits['${line.item.id}'] = {'${line.qty}': line.prixT};
      }
      final created = await VenteService().create(
        VenteCreatePayload(
          depotId: widget.depot.id,
          lieuDeVente: _lieu,
          nomClient: _nomClient.text.trim().isEmpty
              ? 'Passant'
              : _nomClient.text.trim(),
          contactClient: _contact.text.trim(),
          adresse: _adresse.text.trim(),
          monnaie: '${_devise!.id}-${_devise!.libele}',
          updateDevise: _tauxValue,
          tranche: _tranche,
          trancheP: num.tryParse(_trancheP.text.trim()) ?? 0,
          produits: produits,
        ),
      );
      unawaited(
        DepotCatalogStore.applySaleThenRefresh(
          widget.depot.id,
          {for (final line in _lines) line.item.id: line.qty},
        ),
      );
      PageCache.invalidatePrefix('ventes:');
      PageCache.put(PageCache.vente(created.id), created);
      unawaited(
        DepotOpsStore.invalidate(widget.depot.id, DepotOpsStore.ventes),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vente enregistrée")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VenteShowPage(
            venteId: created.id,
            depot: widget.depot,
            initialVente: created,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.red,
          content: Text(e.message),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
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
        title: Text("Nouvelle vente — ${widget.depot.libele}"),
      ),
      body: _loadingForm
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Erreur: $_error"),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadForm,
                          child: const Text("Réessayer"),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _section(
                        title: "Client",
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nomClient,
                              decoration: const InputDecoration(
                                labelText: "Nom client",
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _contact,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: "Téléphone",
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _adresse,
                              decoration: const InputDecoration(
                                labelText: "Adresse",
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_lieu),
                              initialValue: _lieu,
                              decoration: const InputDecoration(
                                labelText: "Lieu de vente",
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Shop',
                                  child: Text('Au shop'),
                                ),
                                DropdownMenuItem(
                                  value: 'Livraison',
                                  child: Text('Livraison'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _lieu = v ?? 'Shop'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        title: "Devise et taux",
                        child: Column(
                          children: [
                            DropdownButtonFormField<_DeviseOption>(
                              key: ValueKey(_devise?.id),
                              initialValue: _devise != null &&
                                      _devises.any((d) => d.id == _devise!.id)
                                  ? _devises.firstWhere(
                                      (d) => d.id == _devise!.id,
                                    )
                                  : null,
                              decoration: const InputDecoration(
                                labelText: "Devise",
                              ),
                              items: _devises
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        "${d.libele}  ·  1 ${d.libele} = ${formatMoney(d.taux)} CDF",
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _selectDevise,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _taux,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    "Taux (1 ${_devise?.libele ?? 'devise'} = ? CDF)",
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                final n = asDouble(v);
                                if (n == null || n <= 0) {
                                  return "Taux invalide";
                                }
                                return null;
                              },
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Prix saisis en CDF"),
                              subtitle: Text(
                                _prixEnCdf
                                    ? "Le PU est en francs congolais"
                                    : "Le PU est en ${_devise?.libele ?? 'devise'}",
                                style: const TextStyle(color: AppColors.gray),
                              ),
                              value: _prixEnCdf,
                              onChanged: (v) => setState(() => _prixEnCdf = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _section(
                        title: "Produits",
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _search,
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                hintText: "Rechercher un produit à ajouter",
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
                                "Tapez pour rechercher un produit",
                                style: TextStyle(color: AppColors.gray),
                              )
                            else if (_available.isEmpty)
                              Text(
                                _stock.isEmpty
                                    ? "Aucun produit en stock"
                                    : "Aucun produit à ajouter",
                                style: const TextStyle(color: AppColors.gray),
                              )
                            else
                              ..._available.take(3).map(
                                    (p) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.add_circle_outline,
                                        color: p.stock <= 0
                                            ? AppColors.gray
                                            : AppColors.blue,
                                      ),
                                      title: Text(p.name),
                                      subtitle: Text(
                                        "Stock ${p.stock} ${p.unite}",
                                        style: TextStyle(
                                          color: p.stock <= 0
                                              ? AppColors.red
                                              : AppColors.gray,
                                        ),
                                      ),
                                      onTap: () => _addProduct(p),
                                    ),
                                  ),
                            if (_lines.isNotEmpty) ...[
                              const Divider(),
                              const Text(
                                "Produits sélectionnés",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              ..._lines.map(_lineCard),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _netPreview(),
                      const SizedBox(height: 12),
                      _section(
                        title: "Paiement",
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Paiement par tranche"),
                              value: _tranche,
                              onChanged: (v) => setState(() => _tranche = v),
                            ),
                            if (_tranche)
                              TextFormField(
                                controller: _trancheP,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      "Avance (${_prixEnCdf ? 'CDF' : (_devise?.libele ?? 'devise')})",
                                ),
                              ),
                          ],
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
                              : const Text("Enregistrer la vente"),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _lineCard(_SaleLine line) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
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
                  tooltip: 'Retirer',
                  onPressed: () => _removeLine(line),
                  icon: const Icon(Icons.close, color: AppColors.red),
                ),
              ],
            ),
            Text(
              "Stock ${_availableStock(line.item)} ${line.item.unite}",
              style: const TextStyle(color: AppColors.gray, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Qté"),
                    onChanged: (v) {
                      setState(() => line.qty = int.tryParse(v) ?? 0);
                    },
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
                      labelText:
                          "PU (${_prixEnCdf ? 'CDF' : (_devise?.libele ?? '')})",
                    ),
                    onChanged: (v) {
                      setState(() => line.prixU = asDouble(v) ?? 0);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Total ${formatMoney(line.prixT)} ${_prixEnCdf ? 'CDF' : (_devise?.libele ?? '')}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _netPreview() {
    final pair = _netPair;
    final libele = _devise?.libele ?? 'USD';
    return Card(
      color: AppColors.black,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Aperçu — net à payer",
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${formatMoney(pair.devise)} $libele",
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${formatMoney(pair.cdf)} CDF",
              style: const TextStyle(color: AppColors.gray, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              "1 $libele = ${formatMoney(_tauxValue)} CDF · ${_lines.length} produit(s)",
              style: const TextStyle(color: AppColors.gray, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DeviseOption {
  _DeviseOption({required this.id, required this.libele, required this.taux});

  final int id;
  final String libele;
  final num taux;

  factory _DeviseOption.fromJson(Map<String, dynamic> json) {
    return _DeviseOption(
      id: asInt(json['id']),
      libele: json['libele']?.toString() ?? '',
      taux: asDouble(json['taux']) ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _DeviseOption && other.id == id && other.libele == libele;

  @override
  int get hashCode => Object.hash(id, libele);
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

class _SaleLine {
  _SaleLine({required this.item, required int qty, required num prixU})
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
