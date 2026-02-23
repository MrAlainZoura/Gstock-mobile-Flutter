class Client {
  final int id;
  final String? name;
  final String? prenom;
  final String? genre;
  final String? tel;
  final String? adresse;
  final String? createdAt;
  final String? updatedAt;
  final String? pieceIdentite;
  final String? numeroPiece;
  final String? imagePiece;

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
  });

  /// Factory pour créer un objet Client depuis un JSON
  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] ?? 0,
      name: json['name'],
      prenom: json['prenom'],
      genre: json['genre'],
      tel: json['tel'],
      adresse: json['adresse'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      pieceIdentite: json['peice_identite'],
      numeroPiece: json['numero_piece'],
      imagePiece: json['image_piece'],
    );
  }

  /// Convertir un objet Client en JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'prenom': prenom,
      'genre': genre,
      'tel': tel,
      'adresse': adresse,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'peice_identite': pieceIdentite,
      'numero_piece': numeroPiece,
      'image_piece': imagePiece,
    };
  }

  
}