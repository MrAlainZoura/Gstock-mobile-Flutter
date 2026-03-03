import 'depot.dart';
import '../mapper/depot_mapper.dart';

class User {
  final int id;
  final String name;
  final String email;
  final DateTime? emailVerifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
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
  final DateTime? deletedAt;
  final List<Depot>? depot;  
  final List<dynamic>? depotUser; 
  final List<dynamic>? souscription; 
  final UserRole? userRole; 

  User({
    required this.id,
    required this.name,
    required this.email,
    this.emailVerifiedAt,
    required this.createdAt,
    required this.updatedAt,
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
    this.deletedAt,
    this.depot,
    this.depotUser,
    this.souscription,
    this.userRole,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id          : json['id'],
      name        : json['name'],
      email       : json['email'],
      emailVerifiedAt: json['email_verified_at'] != null ? DateTime.parse(json['email_verified_at']) : null,
      createdAt   : DateTime.parse(json['created_at']),
      updatedAt   : DateTime.parse(json['updated_at']),
      genre       : json['genre'],
      naissance   : json['naissance'],
      fonction    : json['fonction'],
      niveauEtude : json['niveauEtude'],
      option      : json['option'],
      adresse     : json['adresse'],
      tel         : json['tel'],
      postnom     : json['postnom'],
      prenom      : json['prenom'],
      image       : json['image'],
      deletedAt   : json['deleted_at'] != null ? DateTime.parse(json['deleted_at']) : null,
      depot       : (json['depot'] != null && json['depot'] is List)
                    ? DepotMapper.fromJsonList(json['depot'] as List<dynamic>)
                    : null,
      depotUser   : json['depotUser'] ?? [],
      souscription: json['souscription'] ?? [],
      
      userRole    : json['user_role'] != null
                    ? UserRole.fromJson(json['user_role'])
                    : null
       );
  }

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

class UserRole {
  final int id;
  final int userId;
  final int roleId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Role? role;

  UserRole({
    required this.id,
    required this.userId,
    required this.roleId,
    required this.createdAt,
    required this.updatedAt,
    this.role
  });

   factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      userId: json['user_id'] is int ? json['user_id'] : int.parse(json['user_id'].toString()),
      roleId: json['role_id'] is int ? json['role_id'] : int.parse(json['role_id'].toString()),
      role: json['role'] != null ? Role.fromJson(json['role']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      "id": id,
      'userId':userId,
      "roleId":roleId,
      "role": role
      };
    }
}

class Role {
  final int id;
  final String libele;
  final DateTime createdAt;
  final DateTime updatedAt;

  Role({
    required this.id,
    required this.libele,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      libele: json['libele'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}