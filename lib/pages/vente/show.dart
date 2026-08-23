import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/vente_service.dart';
import '../../models/depot.dart';
import '../../models/vente.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../widgets/confirm_dialog.dart';
import 'compassassion_create.dart';
import 'create.dart';

/// Détail `GET /ventes/{id}` + paiement créance.
class VenteShowPage extends StatefulWidget {
  const VenteShowPage({super.key, required this.venteId, this.depot});

  final int venteId;
  final Depot? depot;

  @override
  State<VenteShowPage> createState() => _VenteShowPageState();
}

class _VenteShowPageState extends State<VenteShowPage> {
  final _paiment = TextEditingController();
  bool _paying = false;
  bool _loading = true;
  String? _error;
  Vente? _vente;
  Access _access = Access();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paiment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        VenteService().getById(widget.venteId),
        Access.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _vente = results[0] as Vente;
        _access = results[1] as Access;
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

  Future<void> _payer() async {
    final montant = num.tryParse(_paiment.text.trim().replaceAll(' ', ''));
    if (montant == null) return;
    setState(() => _paying = true);
    try {
      await VenteService().payerCreance(widget.venteId, montant);
      if (!mounted) return;
      _paiment.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Paiement enregistré")));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _delete() async {
    if (!_access.canDeleteVente) return;
    final ok = await confirmAction(
      context,
      title: 'Supprimer cette vente ?',
      message:
          'La vente sera envoyée à la corbeille. Cette action est réservée aux administrateurs.',
    );
    if (!ok || !mounted) return;
    try {
      await VenteService().delete(widget.venteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vente supprimée (corbeille)")),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vente = _vente;
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text(
          vente == null
              ? "Détail vente"
              : (vente.code.isEmpty ? "Vente #${vente.id}" : vente.code),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text("Erreur: $_error"))
          : vente == null
          ? const Center(child: Text("Vente introuvable"))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.list_alt),
                          label: const Text("Aller à la liste"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.depot == null
                              ? null
                              : () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VenteCreatePage(
                                        depot: widget.depot!,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.add),
                          label: const Text("Ajouter une vente"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    children: [
                      _kv("Client", vente.clientName),
                      _kv("Facturé par", vente.vendorName),
                      _kv(
                        "Taux de change",
                        "1 ${vente.deviseLibele} = ${formatMoney(vente.taux)} CDF",
                      ),
                      if (vente.createdAt != null)
                        _kv(
                          "Date",
                          vente.createdAt.toString().split('.').first,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProductsCard(vente: vente),
                  if (!vente.hasCompassassion) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompassassionCreatePage(
                              venteId: widget.venteId,
                              depot: widget.depot,
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Compassassion (échanger produit)'),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Échange l’article de cette vente contre un nouveau. '
                      'Si l’ancien était une pièce, il est écarté de la vente.',
                      style: TextStyle(fontSize: 12, color: AppColors.gray),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _TotalsCard(vente: vente),
                  if (vente.reste > 0) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Encaisser le reste (créance)",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _paiment,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: "Montant (${vente.deviseLibele})",
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _paying ? null : _payer,
                              child: const Text("Payer"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_access.canDeleteVente) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                      ),
                      onPressed: _delete,
                      icon: const Icon(Icons.delete),
                      label: const Text("Supprimer"),
                    ),
                  ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({required this.vente});

  final Vente vente;

  @override
  Widget build(BuildContext context) {
    final hasComp = vente.hasCompassassion;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasComp
                  ? 'Nouveau produit (compassassion)'
                  : 'Produits (venteProduit)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (hasComp) ...[
              if (vente.lignesCompassassion.isEmpty)
                const Text(
                  'Aucun produit compassassion',
                  style: TextStyle(color: AppColors.gray),
                )
              else
                ...vente.lignesCompassassion.map((l) => _ligne(vente, l)),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Produit vente initiale (venteProduit)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray,
                ),
              ),
              const SizedBox(height: 4),
              if (vente.lignes.isEmpty)
                const Text(
                  'Aucun produit venteProduit',
                  style: TextStyle(color: AppColors.gray),
                )
              else
                ...vente.lignes.map((l) => _ligne(vente, l, referenced: true)),
            ] else if (vente.lignes.isEmpty)
              const Text(
                'Aucun produit',
                style: TextStyle(color: AppColors.gray),
              )
            else
              ...vente.lignes.map((l) => _ligne(vente, l)),
          ],
        ),
      ),
    );
  }

  Widget _ligne(Vente vente, VenteLigne l, {bool referenced = false}) {
    final unite = (l.unite != null && l.unite!.isNotEmpty) ? l.unite! : 'pcs';
    final color = referenced ? AppColors.gray : AppColors.black;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            referenced ? "Réf. ${l.libele}" : l.libele,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
              fontStyle: referenced ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Qté ${formatMoney(l.quantite)} $unite",
            style: const TextStyle(color: AppColors.gray),
          ),
          Text(
            "PU ${vente.moneyLabel(l.prixU)}",
            style: const TextStyle(color: AppColors.gray),
          ),
          Text(
            "Total ${vente.moneyLabel(l.prixT)}",
            style: const TextStyle(color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.vente});

  final Vente vente;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row("Net à payer", vente.moneyLabel(vente.netAPayer), bold: true),
            _row("Paiement reçu", vente.moneyLabel(vente.paiementRecu)),
            if (vente.isTranche)
              _row(
                "Reste (tranche)",
                vente.moneyLabel(vente.reste),
                valueColor: vente.reste > 0 ? AppColors.red : AppColors.black,
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.gray,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
