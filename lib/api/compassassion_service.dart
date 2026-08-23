import '../models/vente.dart';
import '../utils/methode.dart';
import 'api_client.dart';
import 'api_response.dart';

/// Compassassion (échange produit d'une vente) — `POST /compassassions`.
class CompassassionService {
  final ApiClient _api = ApiClient.instance;

  /// `GET /compassassions/depot/{depot}` — ventes ayant une compassassion.
  Future<List<Vente>> listByDepot(int depotId) async {
    final res = await _api.get('compassassions/depot/$depotId');
    final data = asMap(res.data);
    final raw = data?['compassassion'] ?? data?['compassassions'] ?? res.data;
    return asList(raw)
        .whereType<Map>()
        .map((e) => Vente.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /compassassions/vente/{vente}/create`
  Future<Map<String, dynamic>> getCreateForm(int venteId) async {
    final res = await _api.get('compassassions/vente/$venteId/create');
    return asMap(res.data) ?? {};
  }

  /// `POST /compassassions` — même structure `produits` que les ventes.
  Future<Vente> create({
    required int venteId,
    required Map<String, Map<String, num>> produits,
  }) async {
    final res = await _api.post(
      'compassassions',
      body: {
        'vente_id': venteId,
        'produits': produits,
      },
    );
    final data = asMap(res.data);
    if (data == null) {
      throw ApiException('Compassassion enregistrée mais réponse invalide');
    }
    return Vente.fromJson(data);
  }

  /// `DELETE /compassassions/{id}` — annule la compassassion du jour.
  Future<void> delete(int id) async {
    await _api.delete('compassassions/$id');
  }
}
