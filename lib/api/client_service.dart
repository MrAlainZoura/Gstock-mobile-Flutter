import '../mapper/client_mapper.dart';
import '../models/client.dart';
import '../utils/methode.dart';
import 'api_client.dart';

class ClientService {
  final ApiClient _api = ApiClient.instance;

  /// `GET /clients/depot/{depot}` — clients avec plus d'une vente sur l'année.
  Future<List<Client>> getByDepot(int depotId) async {
    final res = await _api.get('clients/depot/$depotId');
    final data = asMap(res.data);
    return ClientMapper.fromJsonList(data?['clients'] ?? res.data);
  }

  Future<List<Client>> getMensuel(int depotId) async {
    final res = await _api.get('clients/depot/$depotId/mensuel');
    final data = asMap(res.data);
    return ClientMapper.fromJsonList(data?['clients'] ?? res.data);
  }

  Future<List<Client>> getAnnuel(int depotId) async {
    final res = await _api.get('clients/depot/$depotId/annuel');
    final data = asMap(res.data);
    return ClientMapper.fromJsonList(data?['clients'] ?? res.data);
  }

  Future<Client> getForEdit(int clientId, int depotId) async {
    final res = await _api.get('clients/$clientId/depot/$depotId');
    return ClientMapper.fromJsonSingle({'data': res.data});
  }

  /// `PUT /clients/{id}` — `nom_client`, `contact_client`, `piece`, `numeroPiece`.
  Future<Client> update(int id, Map<String, dynamic> data) async {
    final res = await _api.put('clients/$id', body: data);
    return ClientMapper.fromJsonSingle({'data': res.data});
  }
}
