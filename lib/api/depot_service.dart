import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/depot.dart';
import '../mapper/depot_mapper.dart';
import '../utils/constants.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';


class DepotService {

Future<List<Depot>> getAllDepots() async {
    try{
      final response = await AuthService().queryProtectedData("depots","GET") ;// await http.get(Uri.parse("$baseUrl/Depots"));
        // print(response!.body);
      if (response?.statusCode == 200)  {
        final decoded = jsonDecode(response!.body);
        print(decoded['data'].runtimeType);
      // Vérifie si c'est une Map ou une List
      if (decoded is Map<String, dynamic>) {
        final depotsJson = decoded['data'] as List<dynamic>;
        return DepotMapper.fromJsonList(depotsJson);
      } else if (decoded is List<dynamic>) {
        return DepotMapper.fromJsonList(decoded);
      } else {
        throw Exception("Format JSON inattendu ${decoded.runtimeType}");
      }

        
      } else {
        throw Exception("Erreur API: ${response?.statusCode}");
      }
    } catch (e, stackTrace) {
      print('Erreur lors du parsing des dépôts: $e');
      debugPrintStack(label: 'Trace de l\'erreur', stackTrace: stackTrace);
      return [];
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
