import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../mapper/user_mapper.dart';
import '../utils/constants.dart';
import 'authService.dart';


class ApiService {
Future<List<User>> getAllUsers() async {
    final response = await http.get(Uri.parse("$baseUrl/users"));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // print(UserMapper.fromJsonList(data));
      AuthService().login('a.tshiyanze@gmail.com',"0000");
      return UserMapper.fromJsonList(data);
    } else {
      throw Exception("Erreur API: ${response.statusCode}");
    }
  }

 Future<User> getUserById(int id) async {
  final response = await http.get(Uri.parse("$baseUrl/users/$id"));
  // print("response brute : ${response.body}");
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final userJson = data['data'];  
    return UserMapper.fromJsonSingle(userJson);
  } else {
    throw Exception("Erreur API: ${response.statusCode}");
  }
}

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse("$baseUrl/users"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(userData),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur API: ${response.statusCode}");
    }
  }

  // PUT (mettre à jour un utilisateur)
  Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> userData) async {
    final response = await http.put(
      Uri.parse("$baseUrl/users/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(userData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur API: ${response.statusCode}");
    }
  }
}
