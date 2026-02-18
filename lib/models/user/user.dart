class User {
  final int id;
  final String name;
  final String email;
  final String? genre;
  final String? naissance;
  final String? fonction;
  final String? niveauEtude;
  final String? option;
  final String? adresse;
  final String? tel;
  final String? postnom;
  final String? prenom;
  final String? image;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.genre,
    this.naissance,
    this.fonction,
    this.niveauEtude,
    this.option,
    this.adresse,
    this.tel,
    this.postnom,
    this.prenom,
    this.image,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  // Factory pour convertir JSON -> User
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      genre: json['genre'],
      naissance: json['naissance'],
      fonction: json['fonction'],
      niveauEtude: json['niveauEtude'],
      option: json['option'],
      adresse: json['adresse'],
      tel: json['tel'],
      postnom: json['postnom'],
      prenom: json['prenom'],
      image: json['image'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      deletedAt: json['deleted_at'],
    );
  }

  // Méthode pour convertir User -> JSON (utile pour POST/PUT)
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "genre": genre,
      "naissance": naissance,
      "fonction": fonction,
      "niveauEtude": niveauEtude,
      "option": option,
      "adresse": adresse,
      "tel": tel,
      "postnom": postnom,
      "prenom": prenom,
      "image": image,
      "created_at": createdAt,
      "updated_at": updatedAt,
      "deleted_at": deletedAt,
    };
  }
}