import 'package:flutter/material.dart';
import '../api/auth_service.dart';
import './user/user_index.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController(text: "a.tshiyanze@gmail.com");
  final TextEditingController _passwordController = TextEditingController(text: "0000");

  bool _isLoading = false;

  // void _login() async {
  //   if (_formKey.currentState!.validate()) {
  //     setState(() {
  //       _isLoading = true;
  //     });

  //     // Ici tu peux appeler ton API de login
  //     // await Future.delayed(const Duration(seconds: 2)); // simulation
  //     await AuthService().login('a.tshiyanze@gmail.com',"0000");

  //     setState(() {
  //       _isLoading = false;
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Login réussi !")),

  //     );
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (_) => UserListScreen(),
  //       ),
  //     );
  //   }
  // }
  void _login() async {
  if (_formKey.currentState!.validate()) {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService().login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      // Exemple : afficher le token ou message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connexion réussie : ${await AuthService().getToken()}")),
      );

      // Tu peux ensuite naviguer vers une autre page
      // Navigator.pushReplacementNamed(context, '/home');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserListScreen(),
        )
      );
  //     );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Connexion",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // Champ Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Veuillez entrer votre email";
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return "Email invalide";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Champ Mot de passe
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Mot de passe",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Veuillez entrer votre mot de passe";
                    }
                    if (value.length < 4) {
                      return "Le mot de passe doit contenir au moins 4 caractères";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // Bouton Login
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text("Se connecter"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}