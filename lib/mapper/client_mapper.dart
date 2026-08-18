import '../models/client.dart';
import '../utils/methode.dart';

class ClientMapper {
  static List<Client> fromJsonList(dynamic json) {
    final list = json is Map ? asList(json['data'] ?? json['clients']) : asList(json);
    return list
        .whereType<Map>()
        .map((c) => Client.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  static Client fromJsonSingle(Map<String, dynamic> json) {
    final data = asMap(json['data']);
    if (data != null) {
      final nested = asMap(data['client']);
      return Client.fromJson(nested ?? data);
    }
    final client = asMap(json['client']);
    return Client.fromJson(client ?? json);
  }
}
