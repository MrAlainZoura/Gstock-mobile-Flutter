import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/depot.dart';
import '../mapper/depot_mapper.dart';
import '../utils/constants.dart';
import 'auth_service.dart';


class DepotService {

Future<List<Depot>> getAllDepots() async {
    final response = await AuthService().queryProtectedData("depots","GET") ;// await http.get(Uri.parse("$baseUrl/Depots"));
    if (response?.statusCode == 200)  {
      final data = jsonDecode(response!.body);
      // print(DepotMapper.fromJsonList(data));
      return DepotMapper.fromJsonList(data);
    } else {
      throw Exception("Erreur API: ${response?.statusCode}");
    }
  }

 Future<Depot> getDepotById(int id) async {
  // final response = await http.get(Uri.parse("$baseUrl/Depots/$id"));
  final response = await AuthService().queryProtectedData("depots/$id","GET") ;// await http.get(Uri.parse("$baseUrl/Depots"));

  // print("response brute : ${response.body}");
  if (response?.statusCode == 200) {
    final data = json.decode(response!.body);
    final depotJson = data['data'];  
    return DepotMapper.fromJsonSingle(depotJson);
  } else {
    throw Exception("Erreur API: ${response?.statusCode}");
  }
}

  Future<Map<String, dynamic>> createDepot(Map<String, dynamic> depotData) async {
    final response = await http.post(
      Uri.parse("$baseUrl/Depots"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(depotData),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur API: ${response.statusCode}");
    }
  }

  // PUT (mettre à jour un utilisateur)
  Future<Map<String, dynamic>> updateDepot(int id, Map<String, dynamic>depotData) async {
    final response = await http.put(
      Uri.parse("$baseUrl/Depots/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(depotData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur API: ${response.statusCode}");
    }
  }
}
