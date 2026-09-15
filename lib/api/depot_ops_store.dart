import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';
import '../utils/methode.dart';
import '../utils/period.dart';
import 'page_cache.dart';

/// Cache disque des opérations sur **30 jours glissants** (à partir de now),
/// uniquement pour les dépôts déjà ouverts.
///
/// Conservé après déconnexion. Purge après **1 mois d’inactivité**
/// (`lastActivityAt`). `lastSavedAt` sert au refresh en arrière-plan.
class DepotOpsStore {
  DepotOpsStore._();

  static const ventes = 'ventes';
  static const compassassions = 'compassassions';
  static const reservations = 'reservations';
  static const appros = 'appros';
  static const transferts = 'transferts';
  static const clientsYear = 'clients_year';
  static const clientsMonth = 'clients_month';

  /// Fenêtre de données + délai d’inactivité avant purge.
  static const int windowDays = 30;

  static String _dataKey(int depotId, String resource) =>
      '$storageOpsPrefix${depotId}_$resource';

  static String _metaKey(int depotId, String resource) =>
      '${_dataKey(depotId, resource)}_meta';

  static String _activityKey(int depotId) =>
      '${storageOpsPrefix}activity_$depotId';

  /// Fenêtre glissante : [now − 30 jours → now].
  static PeriodRange cacheWindow([DateTime? at]) {
    final now = at ?? DateTime.now();
    return PeriodRange(
      preset: PeriodPreset.custom,
      from: PeriodRange.dayStart(
        now.subtract(const Duration(days: windowDays)),
      ),
      to: PeriodRange.dayEnd(now),
    );
  }

  /// Marque le dépôt comme ouvert + met à jour l’activité.
  static Future<void> markOpened(int depotId) async {
    if (depotId <= 0) return;
    await pruneInactive();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(storageOpsOpenedKey) ?? [];
    final id = '$depotId';
    if (!raw.contains(id)) {
      await prefs.setStringList(storageOpsOpenedKey, [...raw, id]);
    }
    await _touchActivity(prefs, depotId);
  }

  static Future<bool> isOpened(int depotId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(storageOpsOpenedKey) ?? [])
        .contains('$depotId');
  }

  static Future<DateTime?> lastSavedAt(int depotId, String resource) async {
    if (!await isOpened(depotId)) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey(depotId, resource));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = asMap(jsonDecode(raw));
      return asDateTime(map?['lastSavedAt']);
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> lastActivityAt(int depotId) async {
    final prefs = await SharedPreferences.getInstance();
    return asDateTime(prefs.getString(_activityKey(depotId)));
  }

  /// Lit le snapshot (JSON brut). Filtre déjà à la fenêtre 30 jours.
  static Future<List<Map<String, dynamic>>?> readMonth(
    int depotId,
    String resource,
  ) async {
    await pruneInactive();
    if (!await isOpened(depotId)) return null;
    final prefs = await SharedPreferences.getInstance();
    await _touchActivity(prefs, depotId);
    final raw = prefs.getString(_dataKey(depotId, resource));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      final items = asList(decoded)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return filterByPeriod(items, cacheWindow());
    } catch (_) {
      return null;
    }
  }

  /// Écrit le snapshot (fenêtre 30 j) + `lastSavedAt` / activité.
  static Future<void> writeMonth(
    int depotId,
    String resource,
    List<Map<String, dynamic>> items, {
    DateTime? savedAt,
    String dateKey = 'created_at',
  }) async {
    if (depotId <= 0) return;
    await markOpened(depotId);
    final prefs = await SharedPreferences.getInstance();
    final at = savedAt ?? DateTime.now();
    final windowed = filterByPeriod(items, cacheWindow(at), dateKey: dateKey);
    await prefs.setString(
      _dataKey(depotId, resource),
      jsonEncode(windowed),
    );
    await prefs.setString(
      _metaKey(depotId, resource),
      jsonEncode({
        'lastSavedAt': at.toIso8601String(),
        'windowDays': windowDays,
        'count': windowed.length,
      }),
    );
    await _touchActivity(prefs, depotId);
    await _pruneLegacyMonthKeys(prefs, depotId);
  }

  /// Filtre localement selon une période UI.
  static List<Map<String, dynamic>> filterByPeriod(
    List<Map<String, dynamic>> items,
    PeriodRange period, {
    String dateKey = 'created_at',
  }) {
    return items.where((row) {
      final d = asDateTime(row[dateKey]);
      return d == null || period.contains(d);
    }).toList();
  }

  static Future<void> invalidate(int depotId, String resource) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dataKey(depotId, resource));
    await prefs.remove(_metaKey(depotId, resource));
    PageCache.invalidatePrefix('$resource:');
    if (resource == ventes) {
      PageCache.invalidatePrefix('vente:');
    }
  }

  static Future<void> invalidateDepot(int depotId) async {
    final prefs = await SharedPreferences.getInstance();
    await _removeDepotKeys(prefs, depotId);
  }

  /// Conservé volontairement (déconnexion ne l’appelle plus).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith(storageOpsPrefix) || k == storageOpsOpenedKey,
        )
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Supprime caches ops + catalogue après 30 jours sans activité.
  static Future<void> pruneInactive({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final cutoff = (now ?? DateTime.now())
        .subtract(const Duration(days: windowDays));
    final opened = prefs.getStringList(storageOpsOpenedKey) ?? [];
    final stillOpen = <String>[];

    for (final idStr in opened) {
      final depotId = int.tryParse(idStr) ?? 0;
      if (depotId <= 0) continue;
      final activity = asDateTime(prefs.getString(_activityKey(depotId)));
      final latestSaved = await _latestSavedAt(prefs, depotId);
      final last = _maxDate(activity, latestSaved);
      if (last == null || last.isBefore(cutoff)) {
        await _removeDepotKeys(prefs, depotId);
        await _removeCatalog(prefs, depotId);
      } else {
        stillOpen.add(idStr);
      }
    }
    await prefs.setStringList(storageOpsOpenedKey, stillOpen);

    // Catalogue orphelins (dépôt jamais listé dans opened).
    final catalogIds = <int>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(storageCatalogPrefix)) continue;
      if (k.endsWith('_meta')) continue;
      final id = int.tryParse(k.substring(storageCatalogPrefix.length));
      if (id != null && id > 0) catalogIds.add(id);
    }
    for (final depotId in catalogIds) {
      if (stillOpen.contains('$depotId')) continue;
      final metaRaw = prefs.getString('$storageCatalogPrefix${depotId}_meta');
      final saved = asDateTime(
        asMap(metaRaw == null ? null : _tryDecode(metaRaw))?['lastSavedAt'],
      );
      final activity = asDateTime(prefs.getString(_activityKey(depotId)));
      final last = _maxDate(activity, saved);
      if (last == null || last.isBefore(cutoff)) {
        await _removeCatalog(prefs, depotId);
      }
    }
  }

  static Future<void> _touchActivity(
    SharedPreferences prefs,
    int depotId,
  ) async {
    await prefs.setString(
      _activityKey(depotId),
      DateTime.now().toIso8601String(),
    );
  }

  static Future<DateTime?> _latestSavedAt(
    SharedPreferences prefs,
    int depotId,
  ) async {
    DateTime? latest;
    final prefix = '$storageOpsPrefix${depotId}_';
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(prefix) || !k.endsWith('_meta')) continue;
      try {
        final map = asMap(jsonDecode(prefs.getString(k) ?? ''));
        final d = asDateTime(map?['lastSavedAt']);
        if (d != null && (latest == null || d.isAfter(latest))) latest = d;
      } catch (_) {}
    }
    return latest;
  }

  static DateTime? _maxDate(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  static Map<String, dynamic>? _tryDecode(String raw) {
    try {
      return asMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> _removeDepotKeys(
    SharedPreferences prefs,
    int depotId,
  ) async {
    final prefix = '$storageOpsPrefix${depotId}_';
    final activity = _activityKey(depotId);
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(prefix) || k == activity)
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  static Future<void> _removeCatalog(
    SharedPreferences prefs,
    int depotId,
  ) async {
    await prefs.remove('$storageCatalogPrefix$depotId');
    await prefs.remove('$storageCatalogPrefix${depotId}_meta');
  }

  /// Nettoie d’anciennes clés `…_{yyyy-MM}_resource` si présentes.
  static Future<void> _pruneLegacyMonthKeys(
    SharedPreferences prefs,
    int depotId,
  ) async {
    final re = RegExp('^$storageOpsPrefix${depotId}_\\d{4}-\\d{2}_');
    final keys = prefs.getKeys().where(re.hasMatch).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
