import 'package:flutter/material.dart';

import '../../models/depot.dart';
import '../../utils/access.dart';
import 'create.dart';

class DepotDetailPage extends StatelessWidget {
  final Depot depot;

  const DepotDetailPage({super.key, required this.depot});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Access>(
      future: Access.load(),
      builder: (context, snapshot) {
        final access = snapshot.data ?? Access();
        return Scaffold(
          appBar: AppBar(
            title: const Text("Détails du dépôt"),
            actions: [
              // Sidebar Blade : « Mise à jour » admin uniquement.
              if (access.canEditDepot)
                IconButton(
                  tooltip: 'Modifier',
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DepotEditPage(depot: depot),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nom : ${depot.libele}",
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 12),
                Text("Type : ${depot.type}"),
                const SizedBox(height: 12),
                Text("Pays : ${depot.pays ?? '-'}"),
                const SizedBox(height: 12),
                Text("Devise CDF : ${depot.useCdf ? 'oui' : 'non'}"),
                const SizedBox(height: 12),
                Text("Imprimante : ${depot.printer ?? '-'}"),
              ],
            ),
          ),
        );
      },
    );
  }
}
