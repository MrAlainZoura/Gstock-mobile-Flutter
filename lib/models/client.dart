import '../utils/methode.dart';

class Client {
  final int id;
  /// En base : `name`. À l'écriture API : `nom_client`.
  final String? name;
  final String? prenom;
  final String? genre;
  /// En base : `tel`. À l'écriture API : `contact_client`.
  final String? tel;
  final String? adresse;
  final String? createdAt;
  final String? updatedAt;
  /// En base : `peice_identite`. À l'écriture API : `piece`.
  final String? pieceIdentite;
  /// En base : `numero_piece`. À l'écriture API : `numeroPiece`.
  final String? numeroPiece;
  final String? imagePiece;
  final int? ventesCount;
  final int? reservationsCount;

  Client({
    required this.id,
    this.name,
    this.prenom,
    this.genre,
    this.tel,
    this.adresse,
    this.createdAt,
    this.updatedAt,
    this.pieceIdentite,
    this.numeroPiece,
    this.imagePiece,
    this.ventesCount,
    this.reservationsCount,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: asInt(json['id']),
      name: (json['name'] ?? json['nom_client'])?.toString(),
      prenom: json['prenom']?.toString(),
      genre: json['genre']?.toString(),
      tel: (json['tel'] ?? json['contact_client'])?.toString(),
      adresse: json['adresse']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      pieceIdentite: (json['peice_identite'] ?? json['piece'])?.toString(),
      numeroPiece: (json['numero_piece'] ?? json['numeroPiece'])?.toString(),
      imagePiece: json['image_piece']?.toString(),
      ventesCount: json['ventes_count'] != null ? asInt(json['ventes_count']) : null,
      reservationsCount: json['reservations_count'] != null
          ? asInt(json['reservations_count'])
          : (json['count'] != null ? asInt(json['count']) : null),
    );
  }

  String get displayName {
    final parts = [name, prenom]
        .where((e) => e != null && e.trim().isNotEmpty)
        .join(' ')
        .trim();
    return parts.isEmpty ? 'Client #$id' : parts;
  }

  String get searchText =>
      [displayName, tel, adresse, pieceIdentite, numeroPiece]
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .join(' ')
          .toLowerCase();

  /// Body `PUT /clients/{id}` (JSON ou multipart).
  Map<String, dynamic> toUpdateJson({required int depotId}) {
    return {
      'depot_id': depotId,
      'nom_client': name,
      'prenom': prenom,
      'contact_client': tel,
      'adresse': adresse,
      'genre': genre,
      'piece': pieceIdentite,
      'numeroPiece': numeroPiece,
    };
  }

  Map<String, String> toMultipartFields({required int depotId}) {
    final json = toUpdateJson(depotId: depotId);
    return json.map((k, v) => MapEntry(k, '${v ?? ''}'));
  }
}
