import '../models/produit.dart';
import '../utils/methode.dart';

class ProduitMapper {
  static List<Produit> fromJsonList(dynamic json) {
    final list = json is Map ? asList(json['data']) : asList(json);
    return list
        .whereType<Map>()
        .map((p) => Produit.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  static Produit fromJsonSingle(Map<String, dynamic> json) {
    final data = asMap(json['data']);
    // GET /produits/{id} peut renvoyer une liste dans data.
    if (data == null && json['data'] is List && (json['data'] as List).isNotEmpty) {
      return Produit.fromJson(Map<String, dynamic>.from(json['data'][0] as Map));
    }
    return Produit.fromJson(data ?? json);
  }
}
