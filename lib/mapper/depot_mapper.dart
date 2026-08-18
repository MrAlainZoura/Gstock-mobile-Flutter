import '../models/depot.dart';
import '../utils/methode.dart';

class DepotMapper {
  /// `GET /depots` → `{ success: true, data: [ ... ] }`
  static List<Depot> fromJsonList(dynamic json) {
    final list = json is Map ? asList(json['data']) : asList(json);
    return list
        .whereType<Map>()
        .map((d) => Depot.fromJson(Map<String, dynamic>.from(d)))
        .toList();
  }

  static Depot fromJsonSingle(Map<String, dynamic> json) {
    final data = asMap(json['data']);
    return Depot.fromJson(data ?? json);
  }
}
