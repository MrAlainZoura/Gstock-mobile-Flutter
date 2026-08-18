import 'package:flutter/material.dart';

import '../api/api_response.dart';
import '../api/user_service.dart';
import '../utils/access.dart';

/// Formulaire create `POST /users` / update `PUT /users/{id}`.
/// Create : name, email, password obligatoires.
/// Update : name, email, id — **sans** password.
class UserFormScreen extends StatefulWidget {
  final int? userId;
  const UserFormScreen({super.key, this.userId});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telController = TextEditingController();
  final _fonctionController = TextEditingController();
  String _genre = 'M';
  bool _loading = false;

  bool get _isCreate => widget.userId == null;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      UserService().getUserById(widget.userId!).then((user) {
        if (!mounted) return;
        setState(() {
          _nameController.text = user.name;
          _emailController.text = user.email;
          _telController.text = user.tel ?? '';
          _fonctionController.text = user.fonction ?? '';
          if (user.genre != null && user.genre!.isNotEmpty) {
            _genre = user.genre!;
          }
        });
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final access = await Access.load();
    if (_isCreate && !access.canCreateUser) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Vous ne disposez pas de droit nécessaire pour effectuer cette action !",
          ),
        ),
      );
      return;
    }
    if (!_isCreate && !access.canEditUser(widget.userId!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Modification de profil non autorisée")),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isCreate) {
        await UserService().createUser({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'genre': _genre,
          'naissance': '',
          'fonction': _fonctionController.text.trim(),
          'niveauEtude': '',
          'option': '',
          'adresse': '',
          'tel': _telController.text.trim(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Utilisateur créé")),
        );
      } else {
        await UserService().updateUser(widget.userId!, {
          'id': widget.userId,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'genre': _genre,
          'fonction': _fonctionController.text.trim(),
          'tel': _telController.text.trim(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Utilisateur mis à jour")),
        );
      }
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telController.dispose();
    _fonctionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreate ? "Créer utilisateur" : "Modifier utilisateur"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nom"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Nom requis" : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (value) =>
                    value == null || value.isEmpty ? "Email requis" : null,
              ),
              if (_isCreate)
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Mot de passe (min. 4)",
                  ),
                  validator: (value) {
                    if (!_isCreate) return null;
                    if (value == null || value.length < 4) {
                      return "Mot de passe trop court";
                    }
                    return null;
                  },
                ),
              TextFormField(
                controller: _telController,
                decoration: const InputDecoration(labelText: "Téléphone"),
              ),
              TextFormField(
                controller: _fonctionController,
                decoration: const InputDecoration(labelText: "Fonction"),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_genre),
                initialValue: _genre,
                decoration: const InputDecoration(labelText: "Genre"),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('M')),
                  DropdownMenuItem(value: 'F', child: Text('F')),
                ],
                onChanged: (v) => setState(() => _genre = v ?? 'M'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: Text(_isCreate ? "Créer" : "Mettre à jour"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
