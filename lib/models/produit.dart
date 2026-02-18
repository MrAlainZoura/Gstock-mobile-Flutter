class Produit {
  final int id;
  final int marqueId;
  final String libele;
  final String description;
  final String prix;
  final int? quantite; 
  final String etat;
  final String? image; 
  final String? unite;
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
    this.createdAt,
    this.updatedAt,
  });

  // Factory method to create an instance of Produit from JSON
  factory Produit.fromJson(Map<String, dynamic> json) {
    return Produit(
      id: json['id'],
      marqueId: json['marque_id'],
      libele: json['libele'],
      description: json['description'],
      prix: json['prix'],
      quantite: json['quatite'] ?? json['quatite'],
      etat: json['etat'],
      image: json['image'],
      unite: json['unite'],
      createdAt: DateTime.parse(json['created_at']), // Conversion en DateTime
      updatedAt: DateTime.parse(json['updated_at']), // Conversion en DateTime
    );
  }

  // Method to convert Produit instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marque_id': marqueId,
      'libele': libele,
      'description': description,
      'prix': prix,
      'quatite': quantite,
      'etat': etat,
      'image': image,
      'unite': unite,
      // 'created_at': createdAt.toIso8601String(), // Format de date au format ISO
      // 'updated_at': updatedAt.toIso8601String(), // Format de date au format ISO
    };
  }
}