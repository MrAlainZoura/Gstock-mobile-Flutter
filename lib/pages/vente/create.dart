import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/vente_service.dart';
import '../../models/depot.dart';
import '../../models/vente.dart';

/// Création `POST /ventes`.
///
/// Format `produits` (clés String) :
/// `{ "<produit_id>": { "<quantite>": <prix_total> } }`
/// `monnaie` : `"<devise_id>-<libele>"`, ex. `"2-USD"`.
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
  final _produitId = TextEditingController();
  final _quantite = TextEditingController(text: '1');
  final _total = TextEditingController();
  final _monnaie = TextEditingController(text: '2-USD');
  final _taux = TextEditingController(text: '2800');
  String _lieu = 'comptoir';
  bool _tranche = false;
  final _trancheP = TextEditingController(text: '0');
  bool _loading = false;
  Map<String, dynamic>? _formData;

  @override
  void initState() {
    super.initState();
    VenteService().getCreateForm(widget.depot.id).then((data) {
      if (mounted) setState(() => _formData = data);
    }).catchError((_) {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final produitId = _produitId.text.trim();
      final qte = _quantite.text.trim();
      final total = num.parse(_total.text.trim());
      await VenteService().create(
        VenteCreatePayload(
          depotId: widget.depot.id,
          lieuDeVente: _lieu,
          nomClient: _nomClient.text.trim(),
          contactClient: _contact.text.trim(),
          adresse: _adresse.text.trim(),
          monnaie: _monnaie.text.trim(),
          updateDevise: num.parse(_taux.text.trim()),
          tranche: _tranche,
          trancheP: num.tryParse(_trancheP.text.trim()) ?? 0,
          // Clés String obligatoires (objet JSON, pas un tableau).
          produits: {
            produitId: {qte: total},
          },
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vente enregistrée")),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nomClient.dispose();
    _contact.dispose();
    _adresse.dispose();
    _produitId.dispose();
    _quantite.dispose();
    _total.dispose();
    _monnaie.dispose();
    _taux.dispose();
    _trancheP.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Nouvelle vente — ${widget.depot.libele}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_formData != null)
                Text(
                  "Formulaire API chargé (stock / clients)",
                  style: TextStyle(color: Colors.grey[700]),
                ),
              TextFormField(
                controller: _nomClient,
                decoration: const InputDecoration(
                  labelText: "Nom client (passant = client Passant)",
                ),
              ),
              TextFormField(
                controller: _contact,
                decoration: const InputDecoration(labelText: "Contact client"),
              ),
              TextFormField(
                controller: _adresse,
                decoration: const InputDecoration(labelText: "Adresse"),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_lieu),
                initialValue: _lieu,
                decoration: const InputDecoration(labelText: "Lieu de vente *"),
                items: const [
                  DropdownMenuItem(value: 'comptoir', child: Text('comptoir')),
                  DropdownMenuItem(value: 'réception', child: Text('réception')),
                ],
                onChanged: (v) => setState(() => _lieu = v ?? 'comptoir'),
              ),
              TextFormField(
                controller: _produitId,
                decoration: const InputDecoration(
                  labelText: "ID produit *",
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? "Produit requis" : null,
              ),
              TextFormField(
                controller: _quantite,
                decoration: const InputDecoration(labelText: "Quantité *"),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? "Quantité requise" : null,
              ),
              TextFormField(
                controller: _total,
                decoration: const InputDecoration(
                  labelText: "Prix total ligne *",
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v == null || v.isEmpty ? "Total requis" : null,
              ),
              TextFormField(
                controller: _monnaie,
                decoration: const InputDecoration(
                  labelText: "Monnaie (id-libele, ex. 2-USD)",
                ),
              ),
              TextFormField(
                controller: _taux,
                decoration: const InputDecoration(labelText: "Taux (updateDevise)"),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                title: const Text("Paiement partiel (tranche)"),
                value: _tranche,
                onChanged: (v) => setState(() => _tranche = v),
              ),
              if (_tranche)
                TextFormField(
                  controller: _trancheP,
                  decoration: const InputDecoration(labelText: "Montant avance"),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: const Text("Enregistrer la vente"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
