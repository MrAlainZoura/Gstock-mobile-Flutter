import '../models/user.dart';
import 'package:flutter/foundation.dart';

class UserMapper {
  // Conversion pour une liste d'utilisateurs
  static List<User> fromJsonList(Map<String, dynamic> json) {
    try {
      final dynamic rawData = json['data'];

      if (rawData is List) {
        // data est une liste d'objets
        return rawData
            .map((u) => User.fromJson(u as Map<String, dynamic>))
            .toList();
      } else if (rawData is Map<String, dynamic>) {
        // data est un seul objet
        return [User.fromJson(rawData)];
      } else {
        throw Exception("Format inattendu pour 'data': ${rawData.runtimeType}");
      }
    } catch (e, stackTrace) {
      print('Erreur lors du parsing: $e');
      debugPrintStack(label: 'Trace de l\'erreur', stackTrace: stackTrace);
      return [];
    }
  }


  // Conversion pour un utilisateur unique
  static User fromJsonSingle(Map<String, dynamic> json) {
    // final userJson = json['data'];
    return User.fromJson(json);
  }
}