import '../mapper/produit_mapper.dart';
import '../models/produit.dart';
import 'api_client.dart';

/// `apiResource /produits` — quantité = clé **`quatité`**.
class ProduitService {
  final ApiClient _api = ApiClient.instance;

  Future<List<Produit>> getAll() async {
    final res = await _api.get('produits');
    return ProduitMapper.fromJsonList(res.data);
  }

  Future<Produit> getById(int id) async {
    final res = await _api.get('produits/$id');
    return ProduitMapper.fromJsonSingle({'data': res.data});
  }

  Future<Produit> create(Map<String, dynamic> data) async {
    final res = await _api.post('produits', body: data);
    return ProduitMapper.fromJsonSingle({'data': res.data});
  }

  Future<Produit> update(int id, Map<String, dynamic> data) async {
    final res = await _api.put('produits/$id', body: {...data, 'id': id});
    return ProduitMapper.fromJsonSingle({'data': res.data});
  }

  Future<void> delete(int id) async {
    await _api.delete('produits/$id');
  }

  /// `PUT /produit-depot-doublon` — fusionne les doublons produit_depots.
  Future<void> fusionnerDoublons() async {
    await _api.put('produit-depot-doublon');
  }
}
