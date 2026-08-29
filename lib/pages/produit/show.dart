import 'package:flutter/material.dart';

import '../../api/auth_service.dart';
import '../../api/produit_service.dart';
import '../../models/depot.dart';
import '../../models/produit.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../appro/create.dart';

/// Fiche produit + bouton d'approvisionnement.
class ProduitShowPage extends StatefulWidget {
  const ProduitShowPage({
    super.key,
    required this.produit,
    this.depot,
  });

  final Produit produit;
  final Depot? depot;

  @override
  State<ProduitShowPage> createState() => _ProduitShowPageState();
}

class _ProduitShowPageState extends State<ProduitShowPage> {
  late Produit _produit;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _produit = widget.produit;
    _refresh();
  }

  Future<void> _refresh() async {
    if (_produit.id <= 0) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await ProduitService().getById(_produit.id);
      if (!mounted) return;
      setState(() {
        _produit = Produit(
          id: fresh.id,
          marqueId: fresh.marqueId,
          libele: fresh.libele,
          description: fresh.description,
          prix: fresh.prix,
          quantite: widget.produit.quantite ?? fresh.quantite,
          etat: fresh.etat,
          image: fresh.image,
          unite: fresh.unite,
          marque: fresh.marque ?? widget.produit.marque,
          categorie: fresh.categorie ?? widget.produit.categorie,
          createdAt: fresh.createdAt,
          updatedAt: fresh.updatedAt,
        );
        _refreshing = false;
      });
    } catch (_) {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String? get _imageUrl {
    final img = _produit.image?.trim();
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http')) return img;
    final root = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$root/uploads/produits/$img';
  }

  Future<void> _approvisionner() async {
    final depot = widget.depot;
    if (depot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Point de vente introuvable pour l’appro')),
      );
      return;
    }
    final user = await AuthService().user();
    if (!mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session utilisateur introuvable')),
      );
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ApproCreatePage(
          depot: depot,
          userId: user.id,
          initialProduit: _produit,
        ),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Approvisionnement enregistré')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qte = _produit.quantite ?? 0;
    final unite = (_produit.unite != null && _produit.unite!.isNotEmpty)
        ? _produit.unite!
        : 'pcs';
    final imageUrl = _imageUrl;

    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text(_produit.libele),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 120,
                          child: Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              size: 48,
                              color: AppColors.gray,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: AppColors.blue,
                      ),
                    ),
                  Text(
                    _produit.libele,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _kv('Catégorie', _produit.categorie ?? '—'),
                  _kv('Marque', _produit.marque ?? '—'),
                  _kv('Prix', _produit.prix),
                  _kv(
                    'Stock point de vente',
                    '$qte $unite',
                    valueColor: qte <= 0 ? AppColors.red : AppColors.black,
                  ),
                  _kv('Unité', unite),
                  _kv('État', _produit.etat),
                  if (_produit.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Description',
                      style: TextStyle(color: AppColors.gray),
                    ),
                    const SizedBox(height: 4),
                    Text(_produit.description),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: widget.depot == null ? null : _approvisionner,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Approvisionner ce produit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: AppColors.gray)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
