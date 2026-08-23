import 'package:flutter/material.dart';

import '../../models/depot.dart';
import '../../models/produit.dart';
import '../../utils/app_theme.dart';
import '../produit/show.dart';

enum StockSort { qtyAsc, qtyDesc, nameAsc, nameDesc, categorie, marque }

/// Liste stock type datatable : recherche, filtres, tri (qté 0 → max par défaut).
class StockList extends StatefulWidget {
  const StockList({
    super.key,
    required this.produits,
    this.depot,
    this.onChanged,
  });

  final List<Produit> produits;
  final Depot? depot;
  final VoidCallback? onChanged;

  @override
  State<StockList> createState() => _StockListState();
}

class _StockListState extends State<StockList> {
  final _search = TextEditingController();
  String _query = '';
  String? _categorie;
  String? _marque;
  StockSort _sort = StockSort.qtyAsc;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _categories {
    final values = widget.produits
        .map((p) => p.categorie?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<String> get _marques {
    final source = _categorie == null
        ? widget.produits
        : widget.produits.where((p) => p.categorie == _categorie);
    final values = source
        .map((p) => p.marque?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<Produit> get _rows {
    final q = _query.trim().toLowerCase();
    final filtered = widget.produits.where((p) {
      if (_categorie != null && p.categorie != _categorie) return false;
      if (_marque != null && p.marque != _marque) return false;
      if (q.isEmpty) return true;
      final haystack = [
        p.libele,
        p.marque ?? '',
        p.categorie ?? '',
        p.description,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case StockSort.qtyAsc:
          return (a.quantite ?? 0).compareTo(b.quantite ?? 0);
        case StockSort.qtyDesc:
          return (b.quantite ?? 0).compareTo(a.quantite ?? 0);
        case StockSort.nameAsc:
          return a.libele.toLowerCase().compareTo(b.libele.toLowerCase());
        case StockSort.nameDesc:
          return b.libele.toLowerCase().compareTo(a.libele.toLowerCase());
        case StockSort.categorie:
          return (a.categorie ?? '').toLowerCase().compareTo(
                (b.categorie ?? '').toLowerCase(),
              );
        case StockSort.marque:
          return (a.marque ?? '').toLowerCase().compareTo(
                (b.marque ?? '').toLowerCase(),
              );
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: "Rechercher un produit…",
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        label: "Catégorie",
                        value: _categorie,
                        items: _categories,
                        onChanged: (v) => setState(() {
                          _categorie = v;
                          if (v != null &&
                              _marque != null &&
                              !_marques.contains(_marque)) {
                            _marque = null;
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _FilterDropdown(
                        label: "Marque",
                        value: _marque,
                        items: _marques,
                        onChanged: (v) => setState(() => _marque = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SortDropdown(
                  value: _sort,
                  onChanged: (v) {
                    if (v != null) setState(() => _sort = v);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  "${rows.length} produit(s)",
                  style: const TextStyle(
                    color: AppColors.gray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.produits.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                "Aucun produit en stock",
                style: TextStyle(color: AppColors.gray),
              ),
            ),
          )
        else if (rows.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                "Aucun résultat",
                style: TextStyle(color: AppColors.gray),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            sliver: SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final produit = rows[index];
                final qte = produit.quantite ?? 0;
                final unite =
                    (produit.unite != null && produit.unite!.isNotEmpty)
                        ? produit.unite!
                        : 'pcs';
                final categorie = produit.categorie?.isNotEmpty == true
                    ? produit.categorie!
                    : 'Sans catégorie';
                final marque = produit.marque?.isNotEmpty == true
                    ? produit.marque!
                    : 'Sans marque';
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.blue,
                    ),
                    title: Text(
                      produit.libele,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "$categorie  ·  $marque",
                        style: const TextStyle(color: AppColors.gray),
                      ),
                    ),
                    trailing: Text(
                      "$qte $unite",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: qte <= 0 ? AppColors.red : AppColors.black,
                      ),
                    ),
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProduitShowPage(
                            produit: produit,
                            depot: widget.depot,
                          ),
                        ),
                      );
                      if (changed == true) widget.onChanged?.call();
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value != null && items.contains(value) ? value : null,
          isExpanded: true,
          hint: const Text("Toutes"),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text("Toutes", overflow: TextOverflow.ellipsis),
            ),
            ...items.map(
              (e) => DropdownMenuItem<String?>(
                value: e,
                child: Text(e, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final StockSort value;
  final ValueChanged<StockSort?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: "Trier par",
        prefixIcon: Icon(Icons.sort),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<StockSort>(
          value: value,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: StockSort.qtyAsc,
              child: Text("Quantité : 0 → plus grand"),
            ),
            DropdownMenuItem(
              value: StockSort.qtyDesc,
              child: Text("Quantité : plus grand → 0"),
            ),
            DropdownMenuItem(
              value: StockSort.nameAsc,
              child: Text("Produit A → Z"),
            ),
            DropdownMenuItem(
              value: StockSort.nameDesc,
              child: Text("Produit Z → A"),
            ),
            DropdownMenuItem(
              value: StockSort.categorie,
              child: Text("Catégorie"),
            ),
            DropdownMenuItem(
              value: StockSort.marque,
              child: Text("Marque"),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
