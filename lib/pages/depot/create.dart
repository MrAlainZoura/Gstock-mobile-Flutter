import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/auth_service.dart';
import '../../api/depot_service.dart';
import '../../models/depot.dart';
import '../../utils/access.dart';

/// Création `POST /depots` — body : `{ user_id, libele }`.
class DepotCreatePage extends StatefulWidget {
  const DepotCreatePage({super.key});

  @override
  State<DepotCreatePage> createState() => _DepotCreatePageState();
}

class _DepotCreatePageState extends State<DepotCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _libeleController = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final access = await Access.load();
    if (!access.canCreateDepot) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Vous ne disposez pas du droit nécessaire pour créer un point de vente",
          ),
        ),
      );
      return;
    }
    final user = access.user ?? await AuthService().user();
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expirée, reconnectez-vous")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // POST /depots — identifiants réels en base (pas d'IDs masqués Blade).
      await DepotService().createDepot({
        'user_id': user.id,
        'libele': _libeleController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Point de vente créé")),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _libeleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un point de vente")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _libeleController,
                decoration: const InputDecoration(
                  labelText: "Libellé",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Libellé requis" : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Créer"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mise à jour `PUT /depots/{id}` — body : `{ id, libele }`.
class DepotEditPage extends StatefulWidget {
  const DepotEditPage({super.key, required this.depot});

  final Depot depot;

  @override
  State<DepotEditPage> createState() => _DepotEditPageState();
}

class _DepotEditPageState extends State<DepotEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _libeleController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _libeleController = TextEditingController(text: widget.depot.libele);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final access = await Access.load();
    if (!access.canEditDepot) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Mise à jour du point de vente réservée à l'administrateur",
          ),
        ),
      );
      return;
    }
    if (!access.canWrite(widget.depot)) {
      if (!mounted) return;
      access.showSubscriptionBlocked(context);
      return;
    }
    setState(() => _loading = true);
    try {
      await DepotService().updateDepot(widget.depot.id, {
        'id': widget.depot.id,
        'libele': _libeleController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Point de vente mis à jour")),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _libeleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Modifier le point de vente")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _libeleController,
                decoration: const InputDecoration(
                  labelText: "Libellé",
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? "Libellé requis" : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text("Mettre à jour"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
