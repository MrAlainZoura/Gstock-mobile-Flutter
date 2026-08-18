import '../models/user.dart';
import '../utils/methode.dart';

class UserMapper {
  /// `GET /users` → `{ success: true, data: [ ... ] }`
  static List<User> fromJsonList(dynamic json) {
    final list = json is Map ? asList(json['data']) : asList(json);
    return list
        .whereType<Map>()
        .map((u) => User.fromJson(Map<String, dynamic>.from(u)))
        .toList();
  }

  static User fromJsonSingle(Map<String, dynamic> json) {
    final data = asMap(json['data']);
    return User.fromJson(data ?? json);
  }
}
