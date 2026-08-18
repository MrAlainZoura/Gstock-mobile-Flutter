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
