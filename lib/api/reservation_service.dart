import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  /// `GET /reservations/depot/{depot}/create` — stock, clients, devises.
  Future<Map<String, dynamic>> getCreateForm(int depotId) async {
    final res = await _api.get('reservations/depot/$depotId/create');
    return asMap(res.data) ?? {};
  }

  /// `POST /reservations`
  Future<Reservation> create(ReservationCreatePayload payload) async {
    final ApiResponse res;
    final imagePath = payload.imagePath?.trim();
    if (imagePath != null && imagePath.isNotEmpty) {
      final lower = imagePath.toLowerCase();
      final ext = lower.endsWith('.png')
          ? 'png'
          : lower.endsWith('.webp')
              ? 'webp'
              : lower.endsWith('.gif')
                  ? 'gif'
                  : 'jpg';
      final mime = ext == 'png'
          ? MediaType('image', 'png')
          : ext == 'webp'
              ? MediaType('image', 'webp')
              : ext == 'gif'
                  ? MediaType('image', 'gif')
                  : MediaType('image', 'jpeg');
      final file = await http.MultipartFile.fromPath(
        'image',
        imagePath,
        filename: 'piece_identite.$ext',
        contentType: mime,
      );
      res = await _api.postMultipart(
        'reservations',
        payload.toMultipartFields(),
        files: [file],
      );
    } else {
      res = await _api.post('reservations', body: payload.toJson());
    }
    final data = asMap(res.data);
    if (data == null) {
      throw ApiException('Réservation créée mais réponse invalide');
    }
    return Reservation.fromJson(data);
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

  /// `GET /reservations/depot/{depot}/creance?from=&to=` — défaut : mois en cours.
  Future<List<ReservationCreance>> getCreances(
    int depotId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final q = _dateQuery(from, to);
    final res = await _api.get('reservations/depot/$depotId/creance$q');
    final data = asMap(res.data);
    final raw = data?['creances'] ?? res.data;
    return asList(raw)
        .whereType<Map>()
        .map((e) => ReservationCreance.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `POST /reservations/{id}/paiements` — champ historique **`paiment`**.
  Future<void> payerCreance(int reservationId, num montant) async {
    await _api.post(
      'reservations/$reservationId/paiements',
      body: {'paiment': montant},
    );
  }
}
