import '../models/transfert.dart';
import '../utils/methode.dart';
import 'api_client.dart';
import 'api_response.dart';

class TransfertService {
  final ApiClient _api = ApiClient.instance;

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

  /// `GET /transferts/depot/{depot}?from=&to=`
  Future<List<Transfert>> getByDepot(
    int depotId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _dateQuery(from, to);
    final res = await _api.get('transferts/depot/$depotId$q');
    final data = asMap(res.data);
    final raw = data?['transferts'] ?? res.data;
    return asList(raw)
        .whereType<Map>()
        .map((e) => Transfert.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `GET /transferts/depot/{depot}/create`
  Future<Map<String, dynamic>> getCreateForm(int depotId) async {
    final res = await _api.get('transferts/depot/$depotId/create');
    return asMap(res.data) ?? {};
  }

  /// `POST /transferts`
  Future<Transfert> create({
    required int depotId,
    required int destinationId,
    required Map<String, int> produits,
    String? description,
  }) async {
    final res = await _api.post(
      'transferts',
      body: {
        'depot_id': depotId,
        'destination': destinationId,
        'produits': produits,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    final data = asMap(res.data);
    if (data == null) {
      throw ApiException('Transfert créé mais réponse invalide');
    }
    return Transfert.fromJson(data);
  }

  /// `GET /transferts/{id}`
  Future<Transfert> getById(int id) async {
    final res = await _api.get('transferts/$id');
    final data = asMap(res.data);
    if (data == null) {
      throw ApiException('Transfert introuvable');
    }
    return Transfert.fromJson(data);
  }
}
