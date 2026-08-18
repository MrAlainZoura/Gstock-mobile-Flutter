import '../utils/duree.dart';
import '../utils/methode.dart';
import 'vente.dart';

class Reservation {
  Reservation({
    required this.id,
    required this.userId,
    required this.depotId,
    required this.clientId,
    required this.code,
    required this.statut,
    this.createdAt,
    this.updatedAt,
    this.deviseId = 0,
    this.updateTaux = 1,
    this.deletedAt,
    this.paiement,
    this.reservationProduit,
    this.client,
    this.devise,
    this.user,
  });

  final int id;
  final int userId;
  final int depotId;
  final int clientId;
  final String code;
  final String statut;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int deviseId;
  final double updateTaux;
  final DateTime? deletedAt;
  final List<dynamic>? paiement;
  final List<dynamic>? reservationProduit;
  final dynamic client;
  final dynamic devise;
  final dynamic user;

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: asInt(json['id']),
      userId: asInt(json['user_id']),
      depotId: asInt(json['depot_id']),
      clientId: asInt(json['client_id']),
      code: json['code']?.toString() ?? '',
      statut: json['statut']?.toString() ?? '',
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
      deviseId: asInt(json['devise_id']),
      updateTaux: asDouble(json['updateTaux'] ?? json['taux']) ?? 1,
      deletedAt: asDateTime(json['deleted_at']),
      reservationProduit: asList(
        json['reservationProduit'] ??
            json['reservation_produit'] ??
            json['produitReservation'],
      ),
      paiement: asList(json['paiement'] ?? json['paiements']),
      client: json['client'],
      devise: json['devise'],
      user: json['user'],
    );
  }
}

class ReservationLigne {
  ReservationLigne({
    required this.libele,
    required this.montant,
    this.reduction = 0,
    this.debut,
    this.fin,
    this.periode = '—',
  });

  final String libele;
  final num montant;
  final num reduction;
  final DateTime? debut;
  final DateTime? fin;
  final String periode;
}

extension ReservationDisplay on Reservation {
  String get clientName => _personName(client, fallback: 'Client');

  String get vendorName => _personName(user, fallback: 'Utilisateur');

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

  List<ReservationLigne> get lignes {
    return (reservationProduit ?? []).whereType<Map>().map((raw) {
      final line = Map<String, dynamic>.from(raw);
      final produit = asMap(line['produit']);
      final marque = asMap(produit?['marque']);
      final libele = [
        marque?['libele'],
        produit?['libele'] ?? line['libele'],
      ].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ');
      final debut = asDateTime(line['debut']);
      final fin = asDateTime(line['fin']);
      return ReservationLigne(
        libele: libele.isEmpty ? 'Produit' : libele,
        montant: asDouble(line['montant']) ?? 0,
        reduction: asDouble(line['reduction']) ?? 0,
        debut: debut,
        fin: fin,
        periode: formatPeriode(debut, fin),
      );
    }).toList();
  }

  DateTime? get dateDebut {
    final dates = lignes.map((l) => l.debut).whereType<DateTime>();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime? get dateFin {
    final dates = lignes.map((l) => l.fin).whereType<DateTime>();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String get periode => formatPeriode(dateDebut, dateFin);

  /// Un produit : son nom. Plusieurs : `Nom ...`
  String get productSummary {
    final rows = lignes;
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
    return lignes.fold<num>(0, (sum, l) => sum + l.montant);
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
      statut,
      clientName,
      vendorName,
      productSummary,
      periode,
      ...lignes.map((l) => '${l.libele} ${l.periode}'),
      createdAt?.toString() ?? '',
      deletedAt?.toString() ?? '',
    ].join(' ').toLowerCase();
  }
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
