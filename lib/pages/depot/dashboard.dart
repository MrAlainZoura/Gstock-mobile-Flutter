import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/dashboard_service.dart';
import '../../api/depot_catalog.dart';
import '../../api/depot_service.dart';
import '../../api/client_service.dart';
import '../../api/user_service.dart';
import '../../models/client.dart';
import '../../models/depot.dart';
import '../../models/monthly_rapport.dart';
import '../../models/produit.dart';
import '../../models/user.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/counts_bar_chart.dart';
import '../../widgets/curved_bottom_nav.dart';
import '../client/index.dart';
import '../reservation/index.dart';
import '../user/user_index.dart';
import '../vente/index.dart';
import '../appro/index.dart';
import '../transfert/index.dart';
import 'index.dart';
import 'stock_list.dart';

/// Dashboard point de vente — `GET /dashboard` + rapport mensuel.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.depot});

  final Depot? depot;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  DashboardData? _data;
  MonthlyRapport? _stats;
  List<Produit> _stock = [];
  List<User> _depotUsers = [];
  List<Client> _loyalClients = [];
  Access _access = Access();
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DashboardService().getDashboard(),
        Access.load(),
      ]);
      if (!mounted) return;
      final dash = results[0] as DashboardData;
      final loaded = results[1] as Access;
      final access = Access(role: loaded.role, user: dash.user ?? loaded.user);
      final visible = access.visibleDepots(dash.depots);
      final depot = widget.depot ?? (visible.isEmpty ? null : visible.first);

      MonthlyRapport? stats;
      List<Produit> stock = [];
      List<User> depotUsers = [];
      if (depot != null) {
        unawaited(DepotCatalogStore.refreshInBackground(depot.id));
        // Users / stats / stock d'abord — clients fidèles en arrière-plan
        // (évite de bloquer SQLite et d'afficher « aucun » utilisateur).
        final futures = <Future>[
          _safeStats(depot.id),
          _safeStock(depot.id),
        ];
        if (access.isAdmin) {
          futures.add(_safeDepotUsers(depot.id));
        }
        final extra = await Future.wait(futures);
        stats = extra[0] as MonthlyRapport?;
        stock = extra[1] as List<Produit>;
        if (access.isAdmin && extra.length > 2) {
          depotUsers = extra[2] as List<User>;
        }
      }

      if (!mounted) return;
      setState(() {
        _data = dash;
        _access = access;
        _stats = stats;
        _stock = stock;
        _depotUsers = depotUsers;
        _loyalClients = [];
        _loading = false;
      });

      if (depot != null) {
        unawaited(_loadLoyalClients(depot.id));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<MonthlyRapport?> _safeStats(int depotId) async {
    try {
      return await DashboardService().getMonthlyStats(depotId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Produit>> _safeStock(int depotId) async {
    try {
      return await DepotService().getProduits(depotId);
    } catch (_) {
      return [];
    }
  }

  Future<List<User>> _safeDepotUsers(int depotId) async {
    try {
      return await UserService().getUsersByDepot(depotId);
    } catch (_) {
      return [];
    }
  }

  Future<List<Client>> _safeLoyalClients(int depotId) async {
    try {
      return await ClientService().getAnnuel(depotId);
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadLoyalClients(int depotId) async {
    final list = await _safeLoyalClients(depotId);
    if (!mounted) return;
    setState(() => _loyalClients = list);
  }

  List<Depot> get _visibleDepots =>
      _access.visibleDepots(_data?.depots ?? []);

  Depot? get _currentDepot {
    if (widget.depot != null) return widget.depot;
    return _visibleDepots.isEmpty ? null : _visibleDepots.first;
  }

  String get _depotTitle {
    final depot = _currentDepot;
    if (depot == null) return 'Chargement…';
    final type = depot.type.trim();
    final libele = depot.libele.trim();
    if (type.isEmpty) return libele;
    if (libele.isEmpty) return type;
    return '$type $libele';
  }

  void _onNav(int i, Depot? depot) {
    setState(() => _navIndex = i);
    if (depot == null || i == 0 || i == 1) return;
    Future<void> open(Widget page) async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      if (mounted) setState(() => _navIndex = 0);
    }

    switch (i) {
      case 2:
        open(ApproIndexPage(depot: depot));
        break;
      case 3:
        open(VenteIndexPage(depot: depot));
        break;
      case 4:
        open(ReservationIndexPage(depot: depot));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final depot = _currentDepot;
    final stats = _stats;
    final showDepotSwitcher = _visibleDepots.length > 1;
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      extendBody: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _navIndex == 1 ? "Stock" : "Dashboard",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              _depotTitle,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (showDepotSwitcher)
            IconButton(
              tooltip: 'Points de vente',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DepotListPage(depots: _visibleDepots),
                  ),
                );
              },
            ),
          ...accountAppBarActions(
            context,
            _access,
            depotId: depot?.id,
            abonnementCurrent: depot?.abonnementCurrent ?? true,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _navIndex == 1
                      ? StockList(
                          produits: _stock,
                          depot: depot,
                          onChanged: _load,
                        )
                      : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PeriodBanner(
                          period: stats?.periodLabel ?? _fallbackPeriod(),
                        ),
                        if (depot != null &&
                            !_access.abonnementCurrent(depot)) ...[
                          const SizedBox(height: 12),
                          const _SubscriptionBanner(),
                        ],
                        const SizedBox(height: 12),
                        if (stats != null) ...[
                          _ActivityCard(stats: stats, depot: depot),
                          const SizedBox(height: 12),
                          _RankingCard(
                            title: "Meilleurs vendeurs",
                            icon: Icons.emoji_events_outlined,
                            empty: "Aucune vente ce mois",
                            items: stats.topVendeurs,
                          ),
                          const SizedBox(height: 12),
                          _RankingCard(
                            title: "Produits les plus vendus",
                            icon: Icons.shopping_bag_outlined,
                            empty: "Aucun produit vendu ce mois",
                            items: stats.topProduitsVendus,
                          ),
                          const SizedBox(height: 12),
                          _RankingCard(
                            title: "Produits les plus réservés",
                            icon: Icons.event_available_outlined,
                            empty: "Aucune réservation ce mois",
                            items: stats.topProduitsReserves,
                          ),
                        ],
                        if (depot != null) ...[
                          const SizedBox(height: 12),
                          _LoyalClientsCard(
                            clients: _loyalClients,
                            depot: depot,
                          ),
                        ],
                        if (_access.isAdmin && depot != null) ...[
                          const SizedBox(height: 12),
                          _DepotUsersCard(
                            users: _depotUsers,
                            depotId: depot.id,
                            abonnementCurrent: depot.abonnementCurrent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: CurvedBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => _onNav(i, depot),
        items: const [
          CurvedNavItem(
            icon: Icons.dashboard,
            label: "Dashboard",
          ),
          CurvedNavItem(
            icon: Icons.inventory,
            label: "Stock",
          ),
          CurvedNavItem(
            icon: Icons.local_shipping_outlined,
            label: "Appro.",
          ),
          CurvedNavItem(
            icon: Icons.shopping_cart,
            label: "Ventes",
          ),
          CurvedNavItem(
            icon: Icons.event_available_outlined,
            label: "Réserv.",
          ),
        ],
      ),
    );
  }
}

String _fallbackPeriod() {
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  final now = DateTime.now();
  final last = DateTime(now.year, now.month + 1, 0);
  return '1 – ${last.day} ${months[now.month - 1]} ${now.year}';
}

class _SubscriptionBanner extends StatelessWidget {
  const _SubscriptionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
      ),
      child: const Text(
        "Abonnement inactif : création / modification indisponibles. "
        "Consultation limitée au mois en cours. "
        "Renouvelez l'abonnement dans les paramètres du point de vente.",
        style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _PeriodBanner extends StatelessWidget {
  const _PeriodBanner({required this.period});

  final String period;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: AppColors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Période en cours : $period",
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.stats, this.depot});

  final MonthlyRapport stats;
  final Depot? depot;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Activité du mois",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Nombre total de ventes, transferts, approvisionnements et réservations",
              style: TextStyle(fontSize: 12, color: AppColors.gray),
            ),
            const SizedBox(height: 16),
            CountsBarChart(
              bars: [
                ChartBar(
                  label: "Ventes",
                  value: stats.ventesCount,
                  color: AppColors.blue,
                ),
                ChartBar(
                  label: "Transferts",
                  value: stats.transfertsCount,
                  color: AppColors.black,
                ),
                ChartBar(
                  label: "Appro.",
                  value: stats.approCount,
                  color: AppColors.gray,
                ),
                ChartBar(
                  label: "Réserv.",
                  value: stats.reservationsCount,
                  color: AppColors.red,
                ),
              ],
            ),
            if (depot != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransfertIndexPage(depot: depot!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Voir les transferts'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.empty,
  });

  final String title;
  final IconData icon;
  final List<RankingItem> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(empty, style: const TextStyle(color: AppColors.gray))
            else
              ...List.generate(items.length, (i) {
                final item = items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            i == 0 ? AppColors.blue : AppColors.black,
                        child: Text(
                          "${i + 1}",
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        item.detail,
                        style: const TextStyle(color: AppColors.gray),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Clients fidèles (≥2 ventes ou réservations sur l'année).
class _LoyalClientsCard extends StatelessWidget {
  const _LoyalClientsCard({required this.clients, required this.depot});

  final List<Client> clients;
  final Depot depot;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: AppColors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Clients fidèles $year',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClientIndexPage(depot: depot),
                      ),
                    );
                  },
                  child: const Text('Voir plus'),
                ),
              ],
            ),
            const Text(
              'Au moins 2 ventes ou 2 réservations cette année',
              style: TextStyle(fontSize: 12, color: AppColors.gray),
            ),
            const SizedBox(height: 8),
            if (clients.isEmpty)
              const Text(
                'Aucun client fidèle pour le moment',
                style: TextStyle(color: AppColors.gray),
              )
            else
              ...clients.take(5).map((c) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.blue,
                    child: Icon(Icons.person, color: AppColors.white, size: 18),
                  ),
                  title: Text(
                    c.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${c.ventesCount ?? 0} vente(s) · ${c.reservationsCount ?? 0} réserv.',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Section utilisateurs du point de vente (admin / super admin).
class _DepotUsersCard extends StatelessWidget {
  const _DepotUsersCard({
    required this.users,
    required this.depotId,
    this.abonnementCurrent = true,
  });

  final List<User> users;
  final int depotId;
  final bool abonnementCurrent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline, color: AppColors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Utilisateurs",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserListScreen(
                          depotId: depotId,
                          abonnementCurrent: abonnementCurrent,
                        ),
                      ),
                    );
                  },
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (users.isEmpty)
              const Text(
                "Aucun utilisateur sur ce point de vente",
                style: TextStyle(color: AppColors.gray),
              )
            else
              ...users.take(5).map((u) {
                final deleted = u.isDeleted;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor:
                        deleted ? AppColors.gray : AppColors.black,
                    child: Icon(
                      deleted ? Icons.person_off : Icons.person,
                      color: AppColors.white,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    u.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration:
                          deleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    deleted ? '${u.email} · Supprimé' : u.email,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
