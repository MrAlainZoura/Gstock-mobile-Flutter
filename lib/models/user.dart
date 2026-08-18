import '../mapper/depot_mapper.dart';
import '../utils/methode.dart';
import 'depot.dart';
import 'depot_user.dart';

class User {
  final int id;
  final String name;
  final String email;
  final DateTime? emailVerifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
  /// Affectations : relation `depotUser` (`depot_users.user_id` → `depot`).
  final List<DepotUser> depotUser;
  final List<dynamic>? souscription;
  final UserRole? userRole;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.emailVerifiedAt,
    this.createdAt,
    this.updatedAt,
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
    this.depotUser = const [],
    this.souscription,
    this.userRole,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: asInt(json['id']),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      emailVerifiedAt: asDateTime(json['email_verified_at']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      genre: json['genre']?.toString(),
      naissance: json['naissance']?.toString(),
      fonction: json['fonction']?.toString(),
      niveauEtude: json['niveauEtude']?.toString(),
      option: json['option']?.toString(),
      adresse: json['adresse']?.toString(),
      tel: json['tel']?.toString(),
      postnom: json['postnom']?.toString(),
      prenom: json['prenom']?.toString(),
      image: json['image']?.toString(),
      deletedAt: asDateTime(json['deleted_at']),
      depot: (json['depot'] is List)
          ? DepotMapper.fromJsonList(json['depot'] as List<dynamic>)
          : null,
      depotUser: DepotUser.listFrom(json['depotUser'] ?? json['depot_user']),
      souscription: asList(json['souscription']),
      userRole: asMap(json['user_role']) != null
          ? UserRole.fromJson(asMap(json['user_role'])!)
          : null,
    );
  }

  /// Dépôts d'affectation (`dashboard.blade.php` : `$user->depotUser` → `$v->depot`).
  List<Depot> assignedDepots([List<Depot> catalog = const []]) {
    final result = <Depot>[];
    final seen = <int>{};
    for (final row in depotUser) {
      final resolved = row.resolve(catalog);
      if (resolved != null && seen.add(resolved.id)) {
        result.add(resolved);
      }
    }
    return result;
  }
  Map<String, dynamic> toCreateJson({required String password}) {
    return {
      'name': name,
      'email': email,
      'password': password,
      'genre': genre,
      'naissance': naissance,
      'fonction': fonction,
      'niveauEtude': niveauEtude ?? '',
      'option': option ?? '',
      'adresse': adresse ?? '',
      'tel': tel,
    };
  }

  /// Body `PUT /users/{id}` : name, email, id requis — pas de password.
  Map<String, dynamic> toUpdateJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'genre': genre,
      'naissance': naissance,
      'fonction': fonction,
      'niveauEtude': niveauEtude,
      'option': option,
      'adresse': adresse,
      'tel': tel,
      'postnom': postnom,
      'prenom': prenom,
    };
  }
}

class UserRole {
  final int id;
  final int userId;
  final int roleId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Role? role;

  UserRole({
    required this.id,
    required this.userId,
    required this.roleId,
    this.createdAt,
    this.updatedAt,
    this.role,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      roleId: asInt(json['role_id']),
      role: asMap(json['role']) != null ? Role.fromJson(asMap(json['role'])!) : null,
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

/// Rôle renvoyé à la racine du login (`role_user`) : Administrateur | Super admin | user.
class Role {
  final int id;
  final String libele;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Role({
    required this.id,
    required this.libele,
    this.createdAt,
    this.updatedAt,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: asInt(json['id']),
      libele: json['libele']?.toString() ?? '',
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  bool get isAdmin => libele == 'Administrateur' || libele == 'Super admin';
  bool get isSuperAdmin => libele == 'Super admin';
}
