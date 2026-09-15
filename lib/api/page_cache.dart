/// Cache mémoire court pour listes / détails (stale-while-revalidate).
///
/// Affiche immédiatement les données déjà vues, puis rafraîchit en arrière-plan.
class PageCache {
  PageCache._();

  static final Map<String, Object> _store = {};

  static String ventes(int depotId, {DateTime? from, DateTime? to}) =>
      'ventes:$depotId:${_d(from)}:${_d(to)}';

  static String vente(int id) => 'vente:$id';

  static String compassassions(int depotId) => 'compassassions:$depotId';

  static String reservations(int depotId, {DateTime? from, DateTime? to}) =>
      'reservations:$depotId:${_d(from)}:${_d(to)}';

  static String reservation(int id) => 'reservation:$id';

  static String appros(int depotId, {DateTime? from, DateTime? to}) =>
      'appros:$depotId:${_d(from)}:${_d(to)}';

  static String transferts(int depotId, {DateTime? from, DateTime? to}) =>
      'transferts:$depotId:${_d(from)}:${_d(to)}';

  static String clients(int depotId) => 'clients:$depotId';

  static String _d(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static T? peek<T>(String key) {
    final v = _store[key];
    if (v is T) return v;
    return null;
  }

  static void put(String key, Object value) {
    _store[key] = value;
  }

  static void remove(String key) => _store.remove(key);

  static void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  static void clear() => _store.clear();
}
