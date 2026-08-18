import '../utils/methode.dart';

class Vente {
  final int id;
  final int userId;
  final int depotId;
  final int clientId;
  final String code;
  final String type;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int deviseId;
  final double updateTaux;
  final DateTime? deletedAt;
  final List<dynamic>? paiement;
  final List<dynamic>? produitVente;
  final List<dynamic>? compassassion;
  final dynamic client;
  final dynamic devise;
  final dynamic user;

  Vente({
    required this.id,
    required this.userId,
    required this.depotId,
    required this.clientId,
    required this.code,
    required this.type,
    this.createdAt,
    this.updatedAt,
    required this.deviseId,
    required this.updateTaux,
    this.deletedAt,
    this.paiement,
    this.produitVente,
    this.compassassion,
    this.client,
    this.devise,
    this.user,
  });

  factory Vente.fromJson(Map<String, dynamic> json) {
    return Vente(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      depotId: asInt(json['depot_id']),
      clientId: asInt(json['client_id']),
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      deviseId: asInt(json['devise_id']),
      updateTaux: asDouble(json['updateTaux'] ?? json['taux']) ?? 1,
      deletedAt: asDateTime(json['deleted_at']),
      produitVente: asList(
        json['venteProduit'] ?? json['vente_produit'] ?? json['produitVente'],
      ),
      compassassion: asList(json['compassassion'] ?? json['compassassions']),
      paiement: asList(json['paiement'] ?? json['paiements']),
      client: json['client'],
      devise: json['devise'],
      user: json['user'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'depot_id': depotId,
      'client_id': clientId,
      'code': code,
      'type': type,
      'devise_id': deviseId,
      'updateTaux': updateTaux,
    };
  }
}

/// Payload `POST /ventes`.
/// `produits` : `{ "<produit_id>": { "<quantite>": <prix_total> } }`
/// `monnaie` : `"<devise_id>-<libele>"`, ex. `"2-USD"`.
class VenteCreatePayload {
  VenteCreatePayload({
    required this.depotId,
    required this.lieuDeVente,
    required this.produits,
    this.nomClient = 'Passant',
    this.prenom = '',
    this.contactClient = '',
    this.adresse = '',
    this.genre = 'M',
    this.monnaie = '2-USD',
    this.updateDevise = 2800,
    this.tranche = false,
    this.trancheP = 0,
  });

  final int depotId;
  final String lieuDeVente;
  final Map<String, Map<String, num>> produits;
  final String nomClient;
  final String prenom;
  final String contactClient;
  final String adresse;
  final String genre;
  final String monnaie;
  final num updateDevise;
  final bool tranche;
  final num trancheP;

  Map<String, dynamic> toJson() {
    return {
      'depot_id': depotId,
      'nom_client': nomClient,
      'prenom': prenom,
      'contact_client': contactClient,
      'adresse': adresse,
      'genre': genre,
      'lieu_de_vente': lieuDeVente,
      'monnaie': monnaie,
      'updateDevise': updateDevise,
      'tranche': tranche,
      'trancheP': trancheP,
      'produits': produits,
    };
  }
}

class VenteLigne {
  VenteLigne({
    required this.libele,
    required this.quantite,
    required this.prixU,
    required this.prixT,
    this.unite,
  });

  final String libele;
  final num quantite;
  final num prixU;
  final num prixT;
  final String? unite;
}

class MoneyPair {
  const MoneyPair({required this.cdf, required this.devise});

  final num cdf;
  final num devise;
}

extension VenteDisplay on Vente {
  String get clientName => _personName(client, fallback: 'Client');

  String get vendorName => _personName(user, fallback: 'Vendeur');

  String get deviseLibele {
    if (devise is String && (devise as String).trim().isNotEmpty) {
      return devise as String;
    }
    final map = asMap(devise);
    final libele = map?['libele']?.toString();
    if (libele != null && libele.isNotEmpty) return libele;
    return 'USD';
  }

  num get taux {
    final t = updateTaux;
    return t == 0 ? 1 : t;
  }

  /// `reference_devise` rempli sur le 1er paiement → montants stockés en CDF.
  bool get amountsStoredInCdf {
    final rows = paiement ?? [];
    if (rows.isEmpty) return false;
    final first = asMap(rows.first);
    final ref = first?['reference_devise'];
    if (ref == null) return false;
    if (ref is String && ref.trim().isEmpty) return false;
    return true;
  }

  /// CDF = devise × taux ; devise = CDF / taux.
  MoneyPair convert(num amount) {
    if (amountsStoredInCdf) {
      return MoneyPair(cdf: amount, devise: amount / taux);
    }
    return MoneyPair(cdf: amount * taux, devise: amount);
  }

  String moneyLabel(num amount) {
    final pair = convert(amount);
    return "${formatMoney(pair.devise)} $deviseLibele / ${formatMoney(pair.cdf)} CDF";
  }

  List<VenteLigne> get lignes => _parseLignes(produitVente);

  List<VenteLigne> get lignesCompassassion => _parseLignes(compassassion);

  bool get hasCompassassion => lignesCompassassion.isNotEmpty;

  /// Produits facturés actuellement (compassassion si elle existe).
  List<VenteLigne> get lignesActives =>
      hasCompassassion ? lignesCompassassion : lignes;

  /// Un produit : son nom. Plusieurs : `Nom ...`
  String get productSummary {
    final rows = lignesActives;
    if (rows.isEmpty) return '—';
    if (rows.length == 1) return rows.first.libele;
    return '${rows.first.libele} ...';
  }

  Map<String, dynamic>? get _lastPaiement {
    final rows = (paiement ?? []).whereType<Map>().toList();
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.last);
  }

  num get netAPayer {
    final last = _lastPaiement;
    if (last != null) return asDouble(last['net']) ?? 0;
    return lignesActives.fold<num>(0, (sum, l) => sum + l.prixT);
  }

  num get reste {
    final last = _lastPaiement;
    if (last != null) return asDouble(last['solde']) ?? 0;
    return 0;
  }

  num get paiementRecu {
    final paid = netAPayer - reste;
    return paid < 0 ? 0 : paid;
  }

  bool get isTranche => reste > 0 || ((paiement ?? []).length > 1);

  String get searchText {
    return [
      code,
      clientName,
      vendorName,
      productSummary,
      ...lignesActives.map((l) => l.libele),
      ...lignes.map((l) => l.libele),
      createdAt?.toString() ?? '',
      deletedAt?.toString() ?? '',
    ].join(' ').toLowerCase();
  }
}

List<VenteLigne> _parseLignes(List<dynamic>? raw) {
  return (raw ?? []).whereType<Map>().map((item) {
    final line = Map<String, dynamic>.from(item);
    final produit = asMap(line['produit']);
    final marque = asMap(produit?['marque']);
    final libele = [
      marque?['libele'],
      produit?['libele'] ?? line['libele'],
    ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
    final qte = asInt(line['quantite'] ?? line['quatité'] ?? line['quatite']);
    final total = asDouble(line['prixT']) ?? 0;
    final unit = asDouble(line['prixU']) ?? (qte == 0 ? 0 : total / qte);
    return VenteLigne(
      libele: libele.isEmpty ? 'Produit retiré' : libele,
      quantite: qte,
      prixU: unit,
      prixT: total,
      unite: produit?['unite']?.toString(),
    );
  }).toList();
}

String _personName(dynamic raw, {String fallback = ''}) {
  final map = asMap(raw);
  if (map == null) return fallback;
  final name = [
    map['name'] ?? map['nom'],
    map['postnom'],
    map['prenom'],
  ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
  return name.isEmpty ? fallback : name;
}

String formatMoney(num value) {
  final negative = value < 0;
  final abs = value.abs();
  final isInt = abs == abs.roundToDouble();
  final parts = abs.toStringAsFixed(isInt ? 0 : 2).split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final left = digits.length - i;
    if (i > 0 && left % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  final formatted = parts.length > 1
      ? '${buf.toString()}.${parts[1]}'
      : buf.toString();
  return negative ? '-$formatted' : formatted;
}

/// Synthèse `GET /paiements/depot/{depot}/creances`.
class VenteCreance {
  VenteCreance({
    required this.id,
    required this.vendeur,
    required this.clientNom,
    required this.clientTel,
    required this.produits,
    required this.tranches,
    required this.net,
    required this.devise,
    this.date,
  });

  final int id;
  final String vendeur;
  final String clientNom;
  final String clientTel;
  final List<String> produits;
  final List<String> tranches;
  final num net;
  final String devise;
  final DateTime? date;

  factory VenteCreance.fromJson(Map<String, dynamic> json) {
    final client = asMap(json['client']);
    return VenteCreance(
      id: asInt(json['id']),
      vendeur: json['vendeur']?.toString().trim() ?? '',
      clientNom: client?['nom']?.toString().trim() ?? '',
      clientTel: client?['tel']?.toString() ?? '',
      produits: asList(json['prod']).map((e) => e.toString()).toList(),
      tranches: asList(json['tranche']).map((e) => e.toString()).toList(),
      net: asDouble(json['net']) ?? 0,
      devise: json['devise']?.toString() ?? '',
      date: asDateTime(client?['date']),
    );
  }

  String get productSummary {
    if (produits.isEmpty) return '—';
    if (produits.length == 1) return produits.first;
    return '${produits.first} ...';
  }

  String get lastTranche => tranches.isEmpty ? '—' : tranches.last;

  String get searchText {
    return [
      id.toString(),
      vendeur,
      clientNom,
      clientTel,
      ...produits,
      ...tranches,
      date?.toString() ?? '',
    ].join(' ').toLowerCase();
  }
}
