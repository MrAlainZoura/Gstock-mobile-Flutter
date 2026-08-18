import '../models/vente.dart';
import '../utils/methode.dart';

class VenteMapper {
  static List<Vente> fromJsonList(dynamic json) {
    final list = json is Map ? asList(json['data']) : asList(json);
    return list
        .whereType<Map>()
        .map((v) => Vente.fromJson(Map<String, dynamic>.from(v)))
        .toList();
  }

  static Vente fromJsonSingle(Map<String, dynamic> json) {
    final data = asMap(json['data']);
    return Vente.fromJson(data ?? json);
  }
}
