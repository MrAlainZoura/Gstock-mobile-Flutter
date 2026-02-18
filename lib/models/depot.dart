class Depot {
  final int id;
  final String userId;
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
    required this.type,
  });

  factory Depot.fromJson(Map<String, dynamic> json) {
    return Depot(
      id: json['id'],
      userId: json['user_id'].toString(),
      libele: json['libele'],
      logo: json['logo'],
      email: json['email'],
      contact1: json['contact1'],
      contact: json['contact'],
      cpostal: json['cpostal'],
      pays: json['pays'],
      province: json['province'],
      ville: json['ville'],
      avenue: json['avenue'],
      idNational: json['idNational'],
      numImpot: json['numImpot'],
      autres: json['autres'],
      remboursementDelay: json['remboursement_delay'],
      lat: json['lat'] != null ? double.parse(json['lat']) : null, 
      lon: json['lon'] != null ? double.parse(json['lon']) : null, 
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'libele': libele,
      'logo': logo,
      'email': email,
      'contact1': contact1,
      'contact': contact,
      'cpostal': cpostal,
      'pays': pays,
      'province': province,
      'ville': ville,
      'avenue': avenue,
      'idNational': idNational,
      'numImpot': numImpot,
      'autres': autres,
      'remboursement_delay': remboursementDelay,
      'lat': lat,
      'lon': lon,
      'type': type,
    };
  }
}