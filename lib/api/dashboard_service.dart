import '../mapper/depot_mapper.dart';
import '../mapper/user_mapper.dart';
import '../models/depot.dart';
import '../models/monthly_rapport.dart';
import '../models/user.dart';
import '../utils/methode.dart';
import 'api_client.dart';
import 'user_service.dart';

/// `GET /dashboard` → `{ depot, depotType, user }`.
class DashboardService {
  final ApiClient _api = ApiClient.instance;

  Future<DashboardData> getDashboard() async {
    final res = await _api.get('dashboard');
    final data = asMap(res.data) ?? {};
    return DashboardData(
      depots: DepotMapper.fromJsonList(data['depot']),
      depotTypes: asList(data['depotType'])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      user: asMap(data['user']) != null
          ? UserMapper.fromJsonSingle(asMap(data['user'])!)
          : null,
    );
  }

  /// `GET /rapports/depot/{depot}/mensuel` — activité du mois en cours.
  Future<MonthlyRapport> getMonthlyStats(int depotId) async {
    final res = await _api.get('rapports/depot/$depotId/mensuel');
    final data = asMap(res.data) ?? {};

    Map<int, String> userNames = {};
    try {
      final users = await UserService().getUsersByDepot(depotId);
      for (final u in users) {
        userNames[u.id] = _joinName(u.name, u.postnom, u.prenom);
      }
    } catch (_) {}

    final ventes = asList(data['ventes']).whereType<Map>();
    final reservations = asList(data['reservations']).whereType<Map>();
    final stock = asList(data['stock']).whereType<Map>();

    return MonthlyRapport(
      label: data['label']?.toString() ?? '',
      periodLabel: _currentMonthPeriodLabel(),
      ventesCount: ventes.length,
      transfertsCount: asList(data['transferts']).length,
      approCount: asList(data['approvisionnements']).length,
      reservationsCount: reservations.length,
      topVendeurs: _topVendeurs(ventes, userNames),
      topProduitsVendus: _topProduitsVendus(stock),
      topProduitsReserves: _topProduitsReserves(reservations),
    );
  }

  List<RankingItem> _topVendeurs(
    Iterable<Map> ventes,
    Map<int, String> userNames,
  ) {
    final counts = <int, int>{};
    final names = Map<int, String>.from(userNames);
    for (final vente in ventes) {
      final map = Map<String, dynamic>.from(vente);
      final userId = asInt(map['user_id']);
      if (userId == 0) continue;
      counts[userId] = (counts[userId] ?? 0) + 1;
      final nested = asMap(map['user']);
      if (nested != null && (names[userId] == null || names[userId]!.isEmpty)) {
        names[userId] = _joinName(
          nested['name']?.toString(),
          nested['postnom']?.toString(),
          nested['prenom']?.toString(),
        );
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(2).map((e) {
      final name = names[e.key];
      return RankingItem(
        name: (name != null && name.isNotEmpty) ? name : 'Vendeur #${e.key}',
        value: e.value,
        detail: e.value <= 1 ? '1 vente' : '${e.value} ventes',
      );
    }).toList();
  }

  List<RankingItem> _topProduitsVendus(Iterable<Map> stock) {
    final items = stock.map((raw) {
      final map = Map<String, dynamic>.from(raw);
      return RankingItem(
        name: map['libele']?.toString() ?? 'Produit',
        value: asInt(map['vente']),
        detail: '${asInt(map['vente'])} pièce(s)',
      );
    }).where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return items.take(2).toList();
  }

  List<RankingItem> _topProduitsReserves(Iterable<Map> reservations) {
    final counts = <String, int>{};
    for (final reservation in reservations) {
      final map = Map<String, dynamic>.from(reservation);
      final lines = asList(
        map['reservationProduit'] ?? map['reservation_produit'],
      );
      for (final line in lines.whereType<Map>()) {
        final produit = asMap(line['produit']);
        final name = produit?['libele']?.toString() ??
            'Produit #${asInt(line['produit_id'])}';
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(2).map((e) {
      return RankingItem(
        name: e.key,
        value: e.value,
        detail: e.value <= 1 ? '1 réservation' : '${e.value} réservations',
      );
    }).toList();
  }
}

String _joinName(String? name, String? postnom, String? prenom) {
  return [name, postnom, prenom]
      .where((e) => e != null && e.trim().isNotEmpty)
      .join(' ')
      .trim();
}

String _currentMonthPeriodLabel() {
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

class DashboardData {
  DashboardData({
    required this.depots,
    required this.depotTypes,
    this.user,
  });

  final List<Depot> depots;
  final List<Map<String, dynamic>> depotTypes;
  final User? user;
}
