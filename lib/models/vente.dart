class Vente {
  final int id;
  final int userId;
  final int depotId;
  final int clientId;
  final String code;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int deviseId;
  final double updateTaux; 
  final DateTime? deletedAt;

  Vente({
    required this.id,
    required this.userId,
    required this.depotId,
    required this.clientId,
    required this.code,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.deviseId,
    required this.updateTaux,
    this.deletedAt,
  });

  // Factory method to create an instance of Vente from JSON
  factory Vente.fromJson(Map<String, dynamic> json) {
    return Vente(
      id: json['id'],
      userId: json['user_id'],
      depotId: json['depot_id'],
      clientId: json['client_id'],
      code: json['code'],
      type: json['type'],
      createdAt: DateTime.parse(json['created_at']), 
      updatedAt: DateTime.parse(json['updated_at']), 
      deviseId: json['devise_id'],
      updateTaux: json['updateTaux'].toDouble(), 
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
    );
  }

  // Method to convert Vente instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'depot_id': depotId,
      'client_id': clientId,
      'code': code,
      'type': type,
      'created_at': createdAt.toIso8601String(), 
      'updated_at': updatedAt.toIso8601String(), 
      'devise_id': deviseId,
      'updateTaux': updateTaux,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}