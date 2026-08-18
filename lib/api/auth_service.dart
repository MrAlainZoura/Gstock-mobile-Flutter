import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mapper/user_mapper.dart';
import '../models/user.dart';
import '../utils/constants.dart';
import 'api_client.dart';
import 'api_response.dart';

/// Auth JWT — le login n'utilise PAS l'enveloppe `{ success, data }`.
/// Token à la racine : `token`. Refresh : `access_token`.
class AuthService {
  final ApiClient _api = ApiClient.instance;

  /// `POST /auth/login` (public).
  /// Identifiant : email, nom ou téléphone (`login` + `password`).
  /// Réponse : `{ user, token, role_user, token_type, expires_in }`.
  Future<bool> login(String login, String password) async {
    final res = await _api.post(
      'auth/login',
      body: {'login': login, 'password': password},
      auth: false,
    );

    final payload = res.data;
    if (payload is! Map) {
      throw ApiException('Réponse login inattendue');
    }

    final token = payload['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Token absent dans la réponse login');
    }

    final prefs = await SharedPreferences.getInstance();
    await _api.saveToken(token);
    await prefs.setString(storageUserKey, jsonEncode(payload['user']));
    await prefs.setString(storageRoleKey, jsonEncode(payload['role_user']));
    return true;
  }

  Future<String?> getToken() => _api.getToken();

  Future<User?> user() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(storageUserKey);
    try {
      if (userString == null) return null;
      return UserMapper.fromJsonSingle(
        jsonDecode(userString) as Map<String, dynamic>,
      );
    } catch (e, stackTrace) {
      debugPrint('Erreur parsing user session: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<Role?> role() async {
    final prefs = await SharedPreferences.getInstance();
    final roleString = prefs.getString(storageRoleKey);
    try {
      if (roleString == null) return null;
      return Role.fromJson(jsonDecode(roleString) as Map<String, dynamic>);
    } catch (e, stackTrace) {
      debugPrint('Erreur parsing rôle: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// `GET /auth/me` — utilisateur + depot, depotUser.depot, souscription, user_role.role.
  Future<User> me() async {
    final res = await _api.get('auth/me');
    if (res.data is Map) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageUserKey, jsonEncode(res.data));
    }
    return UserMapper.fromJsonSingle({'data': res.data});
  }

  /// `POST /auth/logout` puis nettoyage local.
  Future<void> logout() async {
    try {
      await _api.post('auth/logout');
    } catch (_) {
      // On efface quand même la session locale.
    }
    await _api.clearToken();
  }

  /// `PUT /auth/refresh` → `{ access_token, token_type, expires_in }`.
  Future<String> refresh() async {
    final res = await _api.put('auth/refresh');
    final token = (res.data is Map ? res.data['access_token'] : null) as String?;
    if (token == null) throw ApiException('Refresh token invalide');
    await _api.saveToken(token);
    return token;
  }

  /// `PUT /auth/password/{user}` — body : `holdPass`, `password`.
  Future<void> updatePassword({
    required int userId,
    required String holdPass,
    required String password,
  }) async {
    await _api.put(
      'auth/password/$userId',
      body: {'holdPass': holdPass, 'password': password},
    );
  }

  /// `PUT /auth/password/{user}/reset` — remet le mot de passe à `0000`.
  Future<void> resetPassword(int userId) async {
    await _api.put('auth/password/$userId/reset');
  }

  /// Conservé pour compatibilité. Préférer [ApiClient].
  Future<dynamic> queryProtectedData(
    String endpoint,
    String method, {
    Map<String, dynamic>? body,
  }) async {
    return _api.request(method, endpoint, body: body);
  }
}
