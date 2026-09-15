import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../utils/methode.dart';
import 'api_client.dart';
import 'depot_ops_store.dart';

/// Cache local du catalogue dépôt (produits + devises) pour les formulaires
/// vente / réservation. Lecture immédiate, rafraîchissement en arrière-plan.
///
/// Conservé après déconnexion. Purge avec les ops après 30 j d’inactivité.
/// `lastSavedAt` sert aux updates différés. Le stock est ajusté localement
/// à chaque opération qui le touche, puis resync API.
class DepotCatalogStore {
  static String _key(int depotId) => '$storageCatalogPrefix$depotId';

  static String _metaKey(int depotId) => '${_key(depotId)}_meta';

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

  static Future<DateTime?> lastSavedAt(int depotId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey(depotId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = asMap(jsonDecode(raw));
      return asDateTime(map?['lastSavedAt']);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int depotId, Map<String, dynamic> payload) async {
    await DepotOpsStore.markOpened(depotId);
    final prefs = await SharedPreferences.getInstance();
    final at = DateTime.now();
    await prefs.setString(
      _key(depotId),
      jsonEncode({
        'depot': payload['depot'],
        'devises': payload['devises'],
        'produits': payload['produits'],
      }),
    );
    await prefs.setString(
      _metaKey(depotId),
      jsonEncode({'lastSavedAt': at.toIso8601String()}),
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

  /// Ajuste le stock local (`delta` négatif = sortie, positif = entrée).
  static Future<void> adjustStock(
    int depotId,
    Map<int, int> deltas,
  ) async {
    if (deltas.isEmpty) return;
    try {
      final cached = await read(depotId);
      if (cached == null) return;
      final produits = asList(cached['produits'])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      for (final row in produits) {
        final nested = asMap(row['produit']);
        final id = asInt(row['produit_id'] ?? nested?['id'] ?? row['id']);
        final delta = deltas[id];
        if (delta == null || delta == 0) continue;
        final current = asInt(row['quantite'] ?? row['quatité']);
        final next = current + delta;
        row['quantite'] = next < 0 ? 0 : next;
      }
      await write(depotId, {...cached, 'produits': produits});
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
    await adjustStock(
      depotId,
      {for (final e in quantities.entries) e.key: -e.value.abs()},
    );
    await refreshInBackground(depotId);
  }

  /// Entrée stock (appro confirmé), puis resync API.
  static Future<void> applyStockInThenRefresh(
    int depotId,
    Map<int, int> quantities,
  ) async {
    if (quantities.isEmpty) {
      await refreshInBackground(depotId);
      return;
    }
    await adjustStock(depotId, {
      for (final e in quantities.entries) e.key: e.value.abs(),
    });
    await refreshInBackground(depotId);
  }

  /// Sortie stock (transfert / réservation), puis resync API.
  static Future<void> applyStockOutThenRefresh(
    int depotId,
    Map<int, int> quantities,
  ) async {
    await applySaleThenRefresh(depotId, quantities);
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
