import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
    Future<bool> login(String email, String password) async {
    final url = Uri.parse("$baseUrl/auth/login");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    
    // print("reponse brute : ${response.body}");
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];
      final user = data['user'];
      final userRole = data['role_user'];
      // final User user = data['user'];
      // final UserRole userRole = data['role_user'];

      // final userJson = jsonEncode(user.toJson());
      // final userRoleJson = jsonEncode(userRole.toJson());

      // Sauvegarder le token localement
      SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("jwt_token", token);
        await prefs.setString("user", user.toString());
        await prefs.setString("role_role", userRole.toString());

      return true;
    } else {
      return false;
    }
  }

  Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("jwt_token");
  }
  Future<String?> user() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("user");
  }
  Future<String?> role() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("role_role");
  }

  Future<void> logout() async {
    final response = await AuthService().queryProtectedData("auth/logout", "post");
    if (response != null && response.statusCode == 200) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove("jwt_token");
    }
  }

  // method global pour toute query securisee
  Future<http.Response?> queryProtectedData(String endpoint, String method) async {
    final token = await getToken();
    final url = Uri.parse("$baseUrl/$endpoint");

    final headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
    
    switch (method.toUpperCase()) {
      case "GET":
        return await http.get(url, headers: headers);
      case "POST":
        return await http.post(url, headers: headers);
      case "PUT":
        return await http.put(url, headers: headers);
      case "DELETE":
        return await http.delete(url, headers: headers);
      default:
        print(Exception("Méthode HTTP non supportée : $method"));
        return null;
    }
  }
}