import 'package:flutter/material.dart';

import '../../models/depot.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../widgets/account_actions.dart';
import 'create.dart';
import 'dashboard.dart';
import 'show.dart';

class DepotListPage extends StatelessWidget {
  final List<Depot> depots;

  const DepotListPage({super.key, required this.depots});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Access>(
      future: Access.load(),
      builder: (context, snapshot) {
        final access = snapshot.data ?? Access();
        final visible = access.visibleDepots(depots);
        return Scaffold(
          appBar: AppBar(
            title: const Text("Liste des dépôts"),
            actions: accountAppBarActions(context, access),
          ),
          body: visible.isEmpty
              ? Center(
                  child: Text(
                    access.isSimpleUser
                        ? "Aucune affectation de dépôt (depotUser)"
                        : "Aucun dépôt",
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final depot = visible[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DashboardPage(depot: depot),
                          ),
                        );
                      },
                      onLongPress: access.canEditDepot
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DepotDetailPage(depot: depot),
                                ),
                              );
                            }
                          : null,
                      child: Card(
                        color: AppColors.black,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.desktop_windows_outlined,
                                  size: 40,
                                  color: AppColors.white,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "${depot.type} ${depot.libele}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          // Blade `hearder` : Depot+ réservé Super admin / Administrateur (quota).
          floatingActionButton: access.canCreateDepot
              ? FloatingActionButton(
                  tooltip: 'Créer un dépôt',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DepotCreatePage(),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }
}
