import '../utils/methode.dart';
import 'api_client.dart';

/// Approvisionnements produit — `GET|POST /approvisionnements…`.
class ApprovisionnementService {
  final ApiClient _api = ApiClient.instance;

  /// `GET /approvisionnements/depot/{depot}`
  Future<Map<String, dynamic>> listByDepot(int depotId) async {
    final res = await _api.get('approvisionnements/depot/$depotId');
    return asMap(res.data) ?? {};
  }

  /// `GET /approvisionnements/depot/{depot}/create`
  Future<Map<String, dynamic>> getCreateForm(int depotId) async {
    final res = await _api.get('approvisionnements/depot/$depotId/create');
    return asMap(res.data) ?? {};
  }

  /// `POST /approvisionnements` — `produits`: `{ "<id>": <quantite> }`.
  Future<List<Map<String, dynamic>>> create({
    required int depotId,
    required int userId,
    required Map<String, int> produits,
  }) async {
    final res = await _api.post(
      'approvisionnements',
      body: {
        'depot_id': depotId,
        'user_id': userId,
        'produits': produits,
      },
    );
    return asList(res.data)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// `POST /approvisionnements/{appro}/confirm/{action}` — `one` | `all`.
  Future<void> confirm(int approId, String action, {int? depotId}) async {
    await _api.post(
      'approvisionnements/$approId/confirm/$action',
      body: depotId == null ? null : {'depot_id': depotId},
    );
  }

  Future<void> delete(int approId) async {
    await _api.delete('approvisionnements/$approId');
  }
}

class Approvisionnement {
  Approvisionnement({
    required this.id,
    required this.userId,
    required this.depotId,
    required this.produitId,
    required this.quantite,
    this.confirmed,
    this.createdAt,
    this.produitLibele,
    this.userName,
    this.unite,
  });

  final int id;
  final int userId;
  final int depotId;
  final int produitId;
  final int quantite;
  final bool? confirmed;
  final DateTime? createdAt;
  final String? produitLibele;
  final String? userName;
  final String? unite;

  factory Approvisionnement.fromJson(Map<String, dynamic> json) {
    final produit = asMap(json['produit']);
    final marque = asMap(produit?['marque']);
    final user = asMap(json['user']);
    final name = [
      marque?['libele'],
      produit?['libele'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    final userLabel = [
      user?['name'],
      user?['postnom'],
      user?['prenom'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    return Approvisionnement(
      id: asInt(json['id']),
      userId: asInt(json['user_id'] ?? user?['id']),
      depotId: asInt(json['depot_id']),
      produitId: asInt(json['produit_id'] ?? produit?['id']),
      quantite: asInt(json['quantite']),
      confirmed: json['confirmed'] == true ||
          json['confirmed'] == 1 ||
          json['confirm'] == true ||
          json['status']?.toString() == 'confirmed',
      createdAt: asDateTime(json['created_at']),
      produitLibele: name.isEmpty ? 'Produit' : name,
      userName: userLabel.isEmpty ? null : userLabel,
      unite: produit?['unite']?.toString(),
    );
  }
}
