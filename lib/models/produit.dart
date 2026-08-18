import '../utils/methode.dart';

class Produit {
  final int id;
  final int marqueId;
  final String libele;
  final String description;
  final String prix;
  /// Champ historique API : **`quatité`** (pas `quantite`).
  final int? quantite;
  final String etat;
  final String? image;
  final String? unite;
  final String? marque;
  final String? categorie;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Produit({
    required this.id,
    required this.marqueId,
    required this.libele,
    required this.description,
    required this.prix,
    this.quantite,
    required this.etat,
    this.image,
    this.unite,
    this.marque,
    this.categorie,
    this.createdAt,
    this.updatedAt,
  });

  factory Produit.fromJson(Map<String, dynamic> json) {
    final marqueMap = asMap(json['marque']);
    final categorieMap =
        asMap(marqueMap?['categorie']) ?? asMap(json['categorie']);
    return Produit(
      id: asInt(json['id']),
      marqueId: asInt(json['marque_id'] ?? marqueMap?['id']),
      libele: json['libele']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      prix: json['prix']?.toString() ?? '0',
      quantite: json['quatité'] != null
          ? asInt(json['quatité'])
          : (json['quatite'] != null
              ? asInt(json['quatite'])
              : (json['quantite'] != null ? asInt(json['quantite']) : null)),
      etat: json['etat']?.toString() ?? 'actif',
      image: json['image']?.toString(),
      unite: json['unite']?.toString(),
      marque: marqueMap?['libele']?.toString() ??
          (json['marque'] is String ? json['marque'] as String : null),
      categorie: categorieMap?['libele']?.toString() ??
          (json['categorie'] is String ? json['categorie'] as String : null),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  /// Body create/update : la quantité s'envoie sous la clé **`quatité`**.
  Map<String, dynamic> toJson() {
    return {
      if (id != 0) 'id': id,
      'marque_id': marqueId,
      'libele': libele,
      'description': description,
      'prix': prix,
      'quatité': quantite,
      'etat': etat,
      'image': image,
      'unite': unite,
    };
  }
}
