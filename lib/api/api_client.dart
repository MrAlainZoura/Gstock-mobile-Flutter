import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import 'api_response.dart';
import 'session_guard.dart';

/// Client HTTP unique pour `{baseUrl}` :
/// JWT Bearer, JSON, refresh automatique sur 401, multipart pour les uploads.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<void> _sessionExpired() async {
    await clearToken();
    await redirectToLoginOnSessionExpired();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageTokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageTokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageTokenKey);
    await prefs.remove(storageUserKey);
    await prefs.remove(storageRoleKey);
    final catalogKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(storageCatalogPrefix))
        .toList();
    for (final key in catalogKeys) {
      await prefs.remove(key);
    }
  }

  Uri _uri(String path) {
    final cleaned = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl/$cleaned');
  }

  Map<String, String> _headers({String? token, bool json = true}) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final token = auth ? await getToken() : null;
    final url = _uri(path);
    final headers = _headers(token: token);
    final encoded = body == null ? null : jsonEncode(body);

    switch (method.toUpperCase()) {
      case 'GET':
        return http.get(url, headers: headers);
      case 'POST':
        return http.post(url, headers: headers, body: encoded);
      case 'PUT':
        return http.put(url, headers: headers, body: encoded);
      case 'DELETE':
        return http.delete(url, headers: headers, body: encoded);
      default:
        throw ApiException('Méthode HTTP non supportée : $method');
    }
  }

  /// Tente `PUT /auth/refresh` puis réessaie la requête d'origine.
  Future<http.Response> _withRefresh({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    var response = await _send(
      method: method,
      path: path,
      body: body,
      auth: auth,
    );

    final isAuthCall = path.startsWith('auth/');
    if (auth && response.statusCode == 401 && !isAuthCall) {
      try {
        final refresh = await _send(method: 'PUT', path: 'auth/refresh');
        if (refresh.statusCode == 200) {
          final decoded = jsonDecode(refresh.body);
          final newToken = decoded['access_token'] as String?;
          if (newToken != null && newToken.isNotEmpty) {
            await saveToken(newToken);
            response = await _send(
              method: method,
              path: path,
              body: body,
              auth: true,
            );
            if (response.statusCode == 401) {
              await _sessionExpired();
            }
          } else {
            await _sessionExpired();
          }
        } else {
          await _sessionExpired();
        }
      } catch (_) {
        await _sessionExpired();
      }
    }

    return response;
  }

  /// Requête JSON protégée (sauf [auth] = false).
  /// Les routes hors login renvoient en général `{ success, message, data }`.
  Future<ApiResponse<dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final response = await _withRefresh(
      method: method,
      path: path,
      body: body,
      auth: auth,
    );
    return _parse(response);
  }

  Future<ApiResponse<dynamic>> get(String path, {bool auth = true}) =>
      request('GET', path, auth: auth);

  Future<ApiResponse<dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      request('POST', path, body: body, auth: auth);

  Future<ApiResponse<dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      request('PUT', path, body: body, auth: auth);

  Future<ApiResponse<dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      request('DELETE', path, body: body, auth: auth);

  /// Upload `multipart/form-data` (produits, dépenses, clients, admin).
  Future<ApiResponse<dynamic>> postMultipart(
    String path,
    Map<String, String> fields, {
    List<http.MultipartFile> files = const [],
    String method = 'POST',
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(method, _uri(path));
    request.headers.addAll(_headers(token: token, json: false));
    request.fields.addAll(fields);
    request.files.addAll(files);

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _parse(response);
  }

  ApiResponse<dynamic> _parse(http.Response response) {
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'Réponse API illisible (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('success')) {
      final api = ApiResponse.fromJson(decoded, statusCode: response.statusCode);
      if (!api.success || response.statusCode >= 400) {
        final message =
            api.message ?? _messageFromErrors(api.errors) ?? 'Erreur API';
        if (_isAuthFailure(response.statusCode, message, decoded)) {
          // ignore: discarded_futures
          _sessionExpired();
        }
        throw ApiException(
          message,
          statusCode: response.statusCode,
          errors: api.errors ?? decoded,
        );
      }
      return api;
    }

    if (response.statusCode >= 400) {
      final message = decoded is Map
          ? (decoded['message'] as String?) ??
              (decoded['error'] as String?) ??
              _messageFromErrors(decoded['errors'] ?? decoded)
          : null;
      final resolved = message ?? 'Erreur API (${response.statusCode})';
      if (_isAuthFailure(response.statusCode, resolved, decoded)) {
        // ignore: discarded_futures
        _sessionExpired();
      }
      throw ApiException(
        resolved,
        statusCode: response.statusCode,
        errors: decoded,
      );
    }

    // Réponse brute (ex. GET /ventes = tableau, login = objet sans success).
    return ApiResponse(
      success: true,
      data: decoded,
      statusCode: response.statusCode,
    );
  }

  String? _messageFromErrors(dynamic errors) {
    if (errors is String && errors.isNotEmpty) return errors;
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }
    return null;
  }

  bool _isAuthFailure(int statusCode, String message, dynamic decoded) {
    if (statusCode == 401) return true;
    final lower = message.toLowerCase();
    if (lower.contains('token expiré') ||
        lower.contains('token expire') ||
        lower.contains('token invalide') ||
        lower.contains('token absent') ||
        lower.contains('unauthenticated')) {
      return true;
    }
    if (decoded is Map) {
      final err = decoded['error']?.toString().toLowerCase() ?? '';
      if (err.contains('token')) return true;
    }
    return false;
  }
}
