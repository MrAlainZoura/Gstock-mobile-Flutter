import '../models/user.dart';

class UserMapper {
  // Conversion pour une liste d'utilisateurs
  static List<User> fromJsonList(Map<String, dynamic> json) {
    final List usersJson = json['data'];
    return usersJson.map((u) => User.fromJson(u)).toList();
  }

  // Conversion pour un utilisateur unique
  static User fromJsonSingle(Map<String, dynamic> json) {
    final userJson = json['data'];
    return User.fromJson(userJson);
  }
}