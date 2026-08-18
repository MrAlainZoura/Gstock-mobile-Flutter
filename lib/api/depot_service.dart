import '../mapper/depot_mapper.dart';
import '../models/depot.dart';
import '../models/produit.dart';
import '../utils/methode.dart';
import 'api_client.dart';

/// `apiResource /depots` + settings, stock, géoloc, printer, CDF.
class DepotService {
  final ApiClient _api = ApiClient.instance;

  Future<List<Depot>> getAllDepots() async {
    final res = await _api.get('depots');
    return DepotMapper.fromJsonList(res.data);
  }

  Future<Depot> getDepotById(int id) async {
    final res = await _api.get('depots/$id');
    return DepotMapper.fromJsonSingle({'data': res.data});
  }

  /// `GET /depots/meta` — types de dépôt pour les formulaires.
  Future<List<Map<String, dynamic>>> getMeta() async {
    final res = await _api.get('depots/meta');
    return asList(res.data)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// `POST /depots` — `{ user_id, libele }`.
  Future<Depot> createDepot(Map<String, dynamic> depotData) async {
    final res = await _api.post('depots', body: depotData);
    return DepotMapper.fromJsonSingle({'data': res.data});
  }

  /// `PUT /depots/{id}` — `{ id, libele }`.
  Future<Depot> updateDepot(int id, Map<String, dynamic> depotData) async {
    final payload = {...depotData, 'id': id};
    final res = await _api.put('depots/$id', body: payload);
    return DepotMapper.fromJsonSingle({'data': res.data});
  }

  Future<void> deleteDepot(int id) async {
    await _api.delete('depots/$id');
  }

  /// `GET /depots/{depot}/settings`.
  Future<Map<String, dynamic>> getSettings(int depotId) async {
    final res = await _api.get('depots/$depotId/settings');
    return asMap(res.data) ?? {};
  }

  /// `GET /depots/{depot}/produits` — lignes `produitDepot` (qté dispo du dépôt).
  Future<List<Produit>> getProduits(int depotId) async {
    final res = await _api.get('depots/$depotId/produits');
    final data = asMap(res.data);
    final raw = data?['produits'] ?? data?['stock'] ?? res.data;
    return asList(raw).whereType<Map>().map((row) {
      final map = Map<String, dynamic>.from(row);
      final nested = asMap(map['produit']);
      if (nested == null) {
        return Produit.fromJson(map);
      }
      return Produit.fromJson({
        ...nested,
        'quantite': map['quantite'] ?? nested['quantite'] ?? nested['quatité'],
        'quatité': map['quantite'] ?? nested['quatité'] ?? nested['quantite'],
      });
    }).toList();
  }

  /// `PUT /depots/{depot}/geolocalisation/{action}` — action = `auto` | `insert`.
  Future<void> updateGeolocalisation({
    required int depotId,
    required String action,
    double? lonAuto,
    double? latAuto,
    double? lonM,
    double? latM,
  }) async {
    await _api.put(
      'depots/$depotId/geolocalisation/$action',
      body: {
        'lonAuto': lonAuto,
        'latAuto': latAuto,
        'lonM': lonM,
        'latM': latM,
      },
    );
  }

  /// `PUT /depots/{depot}/transaction-money` — bascule `use_cdf`.
  Future<void> toggleTransactionMoney(int depotId) async {
    await _api.put(
      'depots/$depotId/transaction-money',
      body: {'depot_id': depotId},
    );
  }

  /// `PUT /depots/{depot}/printer` — `Pos` ↔ `Android`.
  Future<void> togglePrinter(int depotId, String printer) async {
    await _api.put(
      'depots/$depotId/printer',
      body: {'depot_id': depotId, 'printer': printer},
    );
  }
}
