import '../mapper/vente_mapper.dart';
import '../models/vente.dart';
import '../utils/methode.dart';
import 'api_client.dart';
import 'api_response.dart';

class VenteService {
  final ApiClient _api = ApiClient.instance;

  /// `GET /ventes` — tableau brut (sans enveloppe success).
  Future<List<Vente>> getAll() async {
    final res = await _api.get('ventes');
    return VenteMapper.fromJsonList(res.data);
  }

  /// `GET /ventes/depot/{depot}?from=&to=` — défaut : aujourd'hui.
  Future<List<Vente>> getByDepot(
    int depotId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _dateQuery(from, to);
    final res = await _api.get('ventes/depot/$depotId$q');
    return VenteMapper.fromJsonList(res.data);
  }

  String _dateQuery(DateTime? from, DateTime? to) {
    final params = <String, String>{};
    if (from != null) {
      params['from'] =
          '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    }
    if (to != null) {
      params['to'] =
          '${to.year.toString().padLeft(4, '0')}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';
    }
    if (params.isEmpty) return '';
    return '?${Uri(queryParameters: params).query}';
  }

  /// `GET /ventes/depot/{depot}/create` — catégories, clients, stock.
  Future<Map<String, dynamic>> getCreateForm(int depotId) async {
    final res = await _api.get('ventes/depot/$depotId/create');
    return asMap(res.data) ?? {};
  }

  Future<Vente> getById(int id) async {
    final res = await _api.get('ventes/$id');
    return VenteMapper.fromJsonSingle({'data': res.data});
  }

  /// `POST /ventes` — clés de `produits` en String (objet JSON, pas un tableau).
  Future<Vente> create(VenteCreatePayload payload) async {
    final res = await _api.post('ventes', body: payload.toJson());
    final data = asMap(res.data);
    if (data == null) {
      throw ApiException('Vente enregistrée mais réponse invalide');
    }
    return Vente.fromJson(data);
  }

  /// `DELETE /ventes/{vente}` — soft-delete, remet le stock (admin).
  Future<void> delete(int id) async {
    await _api.delete('ventes/$id');
  }

  Future<List<Vente>> getTrashed(
    int depotId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _dateQuery(from, to);
    final res = await _api.get('ventes/depot/$depotId/trashed$q');
    final data = asMap(res.data);
    final raw = data?['ventes'] ?? data?['vente'] ?? data?['data'] ?? res.data;
    return asList(raw)
        .whereType<Map>()
        .map((e) => Vente.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> restore(int id) async {
    await _api.put('ventes/$id/restore');
  }

  Future<void> forceDelete(int id) async {
    await _api.delete('ventes/$id/force');
  }

  /// `GET /paiements/depot/{depot}/creances?from=&to=` — défaut : mois en cours.
  Future<List<VenteCreance>> getCreances(
    int depotId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _dateQuery(from, to);
    final res = await _api.get('paiements/depot/$depotId/creances$q');
    final data = asMap(res.data);
    final raw = data?['creances'] ?? res.data;
    return asList(raw)
        .whereType<Map>()
        .map((e) => VenteCreance.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /paiements/vente/{vente}` — champ historique **`paiment`**.
  Future<void> payerCreance(int venteId, num montant) async {
    await _api.post('paiements/vente/$venteId', body: {'paiment': montant});
  }
}
