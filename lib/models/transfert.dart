import '../utils/methode.dart';

class Transfert {
  Transfert({
    required this.id,
    required this.userId,
    required this.depotId,
    required this.code,
    required this.destination,
    this.description,
    this.confirm,
    this.receptionUser,
    this.createdAt,
    this.user,
    this.depot,
    this.lignes = const [],
  });

  final int id;
  final int userId;
  final int depotId;
  final String code;
  final String destination;
  final String? description;
  final dynamic confirm;
  final dynamic receptionUser;
  final DateTime? createdAt;
  final dynamic user;
  final dynamic depot;
  final List<TransfertLigne> lignes;

  factory Transfert.fromJson(Map<String, dynamic> json) {
    final rawLignes = asList(
      json['produitTransfert'] ?? json['produit_transfert'],
    );
    return Transfert(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      depotId: asInt(json['depot_id']),
      code: json['code']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      description: json['description']?.toString(),
      confirm: json['confirm'],
      receptionUser: json['receptionUser'] ?? json['reception_user'],
      createdAt: asDateTime(json['created_at']),
      user: json['user'],
      depot: json['depot'],
      lignes: rawLignes
          .whereType<Map>()
          .map((e) => TransfertLigne.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  String get initiateur {
    final map = asMap(user);
    if (map == null) return 'Utilisateur';
    final name = [
      map['name'] ?? map['nom'],
      map['postnom'],
      map['prenom'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    return name.isEmpty ? 'Utilisateur' : name;
  }

  int get totalQuantite =>
      lignes.fold<int>(0, (sum, l) => sum + l.quantite);

  bool get isConfirmed {
    if (confirm == true || confirm == 1) return true;
    if (confirm is String) {
      final v = confirm.toString().toLowerCase();
      return v == '1' || v == 'true' || v == 'oui' || v == 'confirme';
    }
    return receptionUser != null && '$receptionUser'.trim().isNotEmpty;
  }

  String get searchText => [
        code,
        destination,
        description ?? '',
        initiateur,
        ...lignes.map((l) => l.libele),
      ].join(' ').toLowerCase();
}

class TransfertLigne {
  TransfertLigne({
    required this.produitId,
    required this.quantite,
    required this.libele,
  });

  final int produitId;
  final int quantite;
  final String libele;

  factory TransfertLigne.fromJson(Map<String, dynamic> json) {
    final produit = asMap(json['produit']);
    final marque = asMap(produit?['marque']);
    final libele = [
      marque?['libele'],
      produit?['libele'] ?? json['libele'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    return TransfertLigne(
      produitId: asInt(json['produit_id'] ?? produit?['id']),
      quantite: asInt(json['quantite']),
      libele: libele.isEmpty ? 'Produit' : libele,
    );
  }
}

class TransfertDepotOption {
  TransfertDepotOption({
    required this.id,
    required this.label,
  });

  final int id;
  final String label;

  factory TransfertDepotOption.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString().trim() ?? '';
    final libele = json['libele']?.toString().trim() ?? '';
    final label = [
      if (type.isNotEmpty) type,
      if (libele.isNotEmpty) libele,
    ].join(' ');
    return TransfertDepotOption(
      id: asInt(json['id']),
      label: label.isEmpty ? 'Point de vente #${asInt(json['id'])}' : label,
    );
  }
}

class TransfertStockItem {
  TransfertStockItem({
    required this.produitId,
    required this.libele,
    required this.quantite,
    this.unite = 'pcs',
  });

  final int produitId;
  final String libele;
  final int quantite;
  final String unite;

  factory TransfertStockItem.fromJson(Map<String, dynamic> json) {
    final produit = asMap(json['produit']) ?? json;
    final marque = asMap(produit['marque']);
    final libele = [
      marque?['libele'],
      produit['libele'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    return TransfertStockItem(
      produitId: asInt(produit['id'] ?? json['produit_id']),
      libele: libele.isEmpty ? 'Produit' : libele,
      quantite: asInt(json['quantite']),
      unite: produit['unite']?.toString().isNotEmpty == true
          ? produit['unite'].toString()
          : 'pcs',
    );
  }
}
