import '../models/reservation.dart';
import '../utils/methode.dart';
import 'api_client.dart';
import 'api_response.dart';

class ReservationService {
  final ApiClient _api = ApiClient.instance;

  /// `GET /reservations/depot/{depot}?from=&to=` — défaut : aujourd'hui.
  Future<List<Reservation>> getByDepot(
    int depotId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _dateQuery(from, to);
    final res = await _api.get('reservations/depot/$depotId$q');
    final data = asMap(res.data);
    final raw = data?['reservation'] ?? data?['reservations'] ?? res.data;
    return asList(raw)
        .whereType<Map>()
        .map((e) => Reservation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  String _dateQuery(DateTime? from, DateTime? to) {
    final params = <String, String>{};
    if (from != null) {
      params['from'] =
          '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    }
    if (to != null) {
      params['to'] =
          '${to.year.toString().padLeft(4, '0')}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';
    }
    if (params.isEmpty) return '';
    return '?${Uri(queryParameters: params).query}';
  }

  /// `GET /reservations/{id}`
  Future<Reservation> getById(int id) async {
    final res = await _api.get('reservations/$id');
    final data = asMap(res.data);
    if (data == null) {
      throw ApiException('Réservation introuvable');
    }
    return Reservation.fromJson(data);
  }

  /// `GET /reservations/depot/{depot}/trashed?from=&to=` — défaut : mois en cours.
  Future<List<Reservation>> getTrashed(
    int depotId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _dateQuery(from, to);
    final res = await _api.get('reservations/depot/$depotId/trashed$q');
    final data = asMap(res.data);
    final raw = data?['reservations'] ?? data?['reservation'] ?? res.data;
    return asList(raw)
        .whereType<Map>()
        .map((e) => Reservation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> restore(int id) async {
    await _api.put('reservations/$id/restore');
  }

  Future<void> forceDelete(int id) async {
    await _api.delete('reservations/$id/force');
  }

  /// `DELETE /reservations/{id}` — soft-delete (admin).
  Future<void> delete(int id) async {
    await _api.delete('reservations/$id');
  }

  /// `POST /reservations/{id}/paiements` — champ historique **`paiment`**.
  Future<void> payerCreance(int reservationId, num montant) async {
    await _api.post(
      'reservations/$reservationId/paiements',
      body: {'paiment': montant},
    );
  }
}
