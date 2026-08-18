import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../utils/methode.dart';
import 'api_client.dart';

/// Cache local du catalogue dépôt (produits + devises) pour les formulaires
/// vente / réservation. Lecture immédiate, rafraîchissement en arrière-plan.
class DepotCatalogStore {
  static String _key(int depotId) => '$storageCatalogPrefix$depotId';

  static Future<Map<String, dynamic>?> read(int depotId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(depotId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return asMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int depotId, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(depotId),
      jsonEncode({
        'depot': payload['depot'],
        'devises': payload['devises'],
        'produits': payload['produits'],
      }),
    );
  }

  static Future<Map<String, dynamic>> fetchAndStore(int depotId) async {
    final res = await ApiClient.instance.get('ventes/depot/$depotId/create');
    final data = asMap(res.data) ?? {};
    await write(depotId, data);
    return data;
  }

  static Future<void> refreshInBackground(int depotId) async {
    try {
      await fetchAndStore(depotId);
    } catch (_) {}
  }

  /// Décrémente le stock local après une vente, puis rafraîchit l’API.
  static Future<void> applySaleThenRefresh(
    int depotId,
    Map<int, int> quantities,
  ) async {
    if (quantities.isEmpty) {
      await refreshInBackground(depotId);
      return;
    }
    try {
      final cached = await read(depotId);
      if (cached != null) {
        final produits = asList(cached['produits'])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        for (final row in produits) {
          final nested = asMap(row['produit']);
          final id = asInt(
            row['produit_id'] ?? nested?['id'] ?? row['id'],
          );
          final sold = quantities[id];
          if (sold == null || sold <= 0) continue;
          final current = asInt(row['quantite'] ?? row['quatité']);
          final next = current - sold;
          row['quantite'] = next < 0 ? 0 : next;
        }
        await write(depotId, {...cached, 'produits': produits});
      }
    } catch (_) {}
    await refreshInBackground(depotId);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(storageCatalogPrefix))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
