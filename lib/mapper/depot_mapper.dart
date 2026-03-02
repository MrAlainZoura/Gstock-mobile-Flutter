import '../models/depot.dart';
import 'package:flutter/foundation.dart';

// import 'dart:convert';

class DepotMapper {
  // Conversion pour une liste d'utilisateurs
  static List<Depot> fromJsonList0(Map<String, dynamic> json) {
    final List usersJson = json['data'];
    return usersJson.map((u) => Depot.fromJson(u)).toList();
  }
  static List<Depot> fromJsonList(List<dynamic> jsonList) {
    try {
      return jsonList
          .map((d) => Depot.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      print('Erreur lors du parsing des dépôts: $e');
      debugPrintStack(label: 'Trace de l\'erreur', stackTrace: stackTrace);
      return [];
    }
  }

  // Conversion pour un utilisateur unique
  static Depot fromJsonSingle(Map<String, dynamic> json) {
    final userJson = json['data'];
    return Depot.fromJson(userJson);
  }
}