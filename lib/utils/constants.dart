/// Base URL de l'API GStock : `{APP_URL}/api`.
///
/// - iOS simulateur / desktop : `http://127.0.0.1:8000/api`
/// - Android émulateur : `http://10.0.2.2:8000/api`
/// - Téléphone physique : IP LAN de la machine, ex. `http://192.168.1.20:8000/api`
const String baseUrl = "http://127.0.0.1:8000/api";

/// Clés SharedPreferences (token JWT + session locale).
const String storageTokenKey = "jwt_token";
const String storageUserKey = "user";
const String storageRoleKey = "user_role";
const String storageCatalogPrefix = "depot_catalog_";

/// URL publique d'un fichier uploadé (`/uploads/{folder}/{file}`).
String uploadsUrl(String folder, String? fileName) {
  final name = fileName?.trim();
  if (name == null || name.isEmpty) return '';
  if (name.startsWith('http://') || name.startsWith('https://')) return name;
  final root = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  return '$root/uploads/$folder/$name';
}
