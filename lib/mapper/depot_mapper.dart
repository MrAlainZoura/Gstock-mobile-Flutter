import '../models/depot.dart';
// import 'dart:convert';

class DepotMapper {
  // Conversion pour une liste d'utilisateurs
  static List<Depot> fromJsonList(Map<String, dynamic> json) {
    final List usersJson = json['data'];
    return usersJson.map((u) => Depot.fromJson(u)).toList();
  }
  // Conversion pour un utilisateur unique
  static Depot fromJsonSingle(Map<String, dynamic> json) {
    final userJson = json['data'];
    return Depot.fromJson(userJson);
  }
}