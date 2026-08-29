import '../utils/methode.dart';
import 'depot.dart';

/// Affectation `depot_users` : un `user` est rattaché à un dépôt via `depot_id`.
/// Relation Laravel : `User.depotUser` → `DepotUser.depot`.
class DepotUser {
  DepotUser({
    required this.id,
    required this.depotId,
    required this.userId,
    this.depot,
  });

  final int id;
  final int depotId;
  final int userId;
  final Depot? depot;

  factory DepotUser.fromJson(Map<String, dynamic> json) {
    final nested = asMap(json['depot']);
    return DepotUser(
      id: asInt(json['id']),
      depotId: asInt(json['depot_id'] ?? nested?['id']),
      userId: asInt(json['user_id']),
      depot: nested != null ? Depot.fromJson(nested) : null,
    );
  }

  /// Dépôt affiché : objet imbriqué `depot`, sinon id d'affectation.
  Depot? resolve([List<Depot> catalog = const []]) {
    if (depot != null) return depot;
    if (depotId <= 0) return null;
    for (final d in catalog) {
      if (d.id == depotId) return d;
    }
    return Depot(id: depotId, userId: userId, libele: 'Point de vente #$depotId');
  }

  static List<DepotUser> listFrom(dynamic raw) {
    return asList(raw)
        .whereType<Map>()
        .map((e) => DepotUser.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
