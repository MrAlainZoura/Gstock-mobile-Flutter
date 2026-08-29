import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../mapper/client_mapper.dart';
import '../models/client.dart';
import '../utils/methode.dart';
import 'api_client.dart';
import 'api_response.dart';

class ClientService {
  final ApiClient _api = ApiClient.instance;

  /// `GET /clients/depot/{depot}` — clients ≥2 ventes ou réservations (année).
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

  /// `PUT /clients/{id}` — infos + pièce d'identité (multipart si image).
  Future<Client> update(
    int id,
    Client client, {
    required int depotId,
    String? imagePath,
  }) async {
    final ApiResponse res;
    final path = imagePath?.trim();
    if (path != null && path.isNotEmpty) {
      final lower = path.toLowerCase();
      final ext = lower.endsWith('.png')
          ? 'png'
          : lower.endsWith('.webp')
              ? 'webp'
              : 'jpg';
      final mime = ext == 'png'
          ? MediaType('image', 'png')
          : ext == 'webp'
              ? MediaType('image', 'webp')
              : MediaType('image', 'jpeg');
      final file = await http.MultipartFile.fromPath(
        'image',
        path,
        filename: 'piece_identite.$ext',
        contentType: mime,
      );
      res = await _api.postMultipart(
        'clients/$id',
        {
          ...client.toMultipartFields(depotId: depotId),
          '_method': 'PUT',
        },
        files: [file],
        method: 'POST',
      );
    } else {
      res = await _api.put('clients/$id', body: client.toUpdateJson(depotId: depotId));
    }
    return ClientMapper.fromJsonSingle({'data': res.data});
  }
}
