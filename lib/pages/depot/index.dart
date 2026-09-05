import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/depot_catalog.dart';
import '../../models/depot.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../widgets/account_actions.dart';
import 'create.dart';
import 'dashboard.dart';
import 'show.dart';

class DepotListPage extends StatelessWidget {
  final List<Depot> depots;

  const DepotListPage({
    super.key,
    required this.depots,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Access>(
      future: Access.load(),
      builder: (context, snapshot) {
        final access = snapshot.data ?? Access();
        final visible = access.visibleDepots(depots);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6F8),
          appBar: AppBar(
            elevation: 0,
            title: const Text(
              'Points de ventes',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: accountAppBarActions(context, access),
          ),
          body: visible.isEmpty
              ? _EmptyState(
            isSimpleUser: access.isSimpleUser,
          )
              : LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                  ? 3
                  : 2;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  100,
                ),
                gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.95,
                ),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final depot = visible[index];

                  return _DepotCard(
                    depot: depot,
                    canEdit: access.canEditDepot,
                    onTap: () {
                      unawaited(
                        DepotCatalogStore.refreshInBackground(
                          depot.id,
                        ),
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DashboardPage(
                            depot: depot,
                          ),
                        ),
                      );
                    },
                    onLongPress: access.canEditDepot
                        ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DepotDetailPage(
                            depot: depot,
                          ),
                        ),
                      );
                    }
                        : null,
                  );
                },
              );
            },
          ),
          floatingActionButton: access.canCreateDepot
              ? FloatingActionButton.extended(
            tooltip: 'Créer un point de vente',
            icon: const Icon(Icons.add),
            label: const Text('Nouveau PDV'),
            onPressed: () {
              final writable = visible.any(access.canWrite) ||
                  access.isSuperAdmin;

              if (!writable && visible.isNotEmpty) {
                access.showSubscriptionBlocked(context);
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DepotCreatePage(),
                ),
              );
            },
          )
              : null,
        );
      },
    );
  }
}

class _DepotCard extends StatelessWidget {
  final Depot depot;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DepotCard({
    required this.depot,
    required this.canEdit,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF191919),
                Color(0xFF080808),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 27,
                        color: AppColors.white,
                      ),
                    ),
                    if (canEdit)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.more_horiz,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),

                const Spacer(),

// Type du point de vente
                if (depot.type.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      depot.type,
                      style: const TextStyle(
                        color: Color(0xFFFFC107),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        depot.libele,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white70,
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSimpleUser;

  const _EmptyState({
    required this.isSimpleUser,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_outlined,
                size: 40,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSimpleUser
                  ? 'Aucune affectation de point de vente'
                  : 'Aucun point de vente',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSimpleUser
                  ? 'Les points de vente qui vous sont affectés apparaîtront ici.'
                  : 'Créez votre premier point de vente pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

