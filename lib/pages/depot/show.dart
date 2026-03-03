import 'package:flutter/material.dart';
import '../../models/depot.dart';

class DepotDetailPage extends StatelessWidget {
  final Depot depot;

  const DepotDetailPage({Key? key, required this.depot}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Détails du dépôt")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Nom : ${depot.libele}", style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 12),
            Text("Type : ${depot.type}"),
            const SizedBox(height: 12),
            Text("Pays : ${depot.pays}"),
            // ajoute d’autres champs selon ton modèle
          ],
        ),
      ),
    );
  }
}