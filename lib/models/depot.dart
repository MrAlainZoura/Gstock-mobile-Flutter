import '../utils/methode.dart';

class Depot {
  final int id;
  final int userId;
  final String libele;
  final String? logo;
  final String? email;
  final String? contact1;
  final String? contact;
  final String? cpostal;
  final String? pays;
  final String? province;
  final String? ville;
  final String? avenue;
  final String? idNational;
  final String? numImpot;
  final String? autres;
  final String? remboursementDelay;
  final double? lat;
  final double? lon;
  final String type;
  /// Si true, les paiements / dépenses sont traités en CDF (sans multiplier le taux).
  final bool useCdf;
  final String? printer;

  Depot({
    required this.id,
    required this.userId,
    required this.libele,
    this.logo,
    this.email,
    this.contact1,
    this.contact,
    this.cpostal,
    this.pays,
    this.province,
    this.ville,
    this.avenue,
    this.idNational,
    this.numImpot,
    this.autres,
    this.remboursementDelay,
    this.lat,
    this.lon,
    this.type = 'Shop',
    this.useCdf = false,
    this.printer,
  });

  factory Depot.fromJson(Map<String, dynamic> json) {
    return Depot(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      libele: json['libele']?.toString() ?? '',
      logo: json['logo']?.toString(),
      email: json['email']?.toString(),
      contact1: json['contact1']?.toString(),
      contact: json['contact']?.toString(),
      cpostal: json['cpostal']?.toString(),
      pays: json['pays']?.toString(),
      province: json['province']?.toString(),
      ville: json['ville']?.toString(),
      avenue: json['avenue']?.toString(),
      idNational: json['idNational']?.toString(),
      numImpot: json['numImpot']?.toString(),
      autres: json['autres']?.toString(),
      remboursementDelay: json['remboursement_delay']?.toString(),
      lat: asDouble(json['lat']),
      lon: asDouble(json['lon']),
      type: json['type']?.toString().isNotEmpty == true
          ? json['type'].toString()
          : 'Shop',
      useCdf: json['use_cdf'] == true || json['use_cdf'] == 1,
      printer: json['printer']?.toString(),
    );
  }

  /// Body `POST /depots` : `user_id` + `libele`.
  Map<String, dynamic> toCreateJson() => {
        'user_id': userId,
        'libele': libele,
      };

  /// Body `PUT /depots/{id}` : `id` + `libele`.
  Map<String, dynamic> toUpdateJson() => {
        'id': id,
        'libele': libele,
      };
}
