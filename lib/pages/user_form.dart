import 'package:flutter/material.dart';
import '../api/user_service.dart';

class UserFormScreen extends StatefulWidget {
  final int? userId; // null = création, sinon modification
  const UserFormScreen({super.key, this.userId});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      // Charger les données existantes pour modification
      ApiService().getUserById(widget.userId!).then((user) {
        setState(() {
          _nameController.text = user.name;
          _emailController.text = user.email;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userId == null ? "Créer utilisateur" : "Modifier utilisateur"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nom"),
                validator: (value) => value!.isEmpty ? "Nom requis" : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (value) => value!.isEmpty ? "Email requis" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final userData = {
                      "name": _nameController.text,
                      "email": _emailController.text,
                    };

                    try {
                      if (widget.userId == null) {
                        // POST
                        final result = await ApiService().createUser(userData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Utilisateur créé: ${result['name']}")),
                        );
                      } else {
                        // PUT
                        final result = await ApiService().updateUser(widget.userId!, userData);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Utilisateur mis à jour: ${result['name']}")),
                        );
                      }
                      Navigator.pop(context); // Retour à la liste
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur: $e")),
                      );
                    }
                  }
                },
                child: Text(widget.userId == null ? "Créer" : "Mettre à jour"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}