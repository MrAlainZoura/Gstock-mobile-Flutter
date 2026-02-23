import '../models/client.dart';

class ClientMapper {
  static List<Client> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => Client.fromJson(json)).toList();
  }

  static Client fromJsonSingle(Map<String, dynamic> json) {
    return Client.fromJson(json);
  }
}