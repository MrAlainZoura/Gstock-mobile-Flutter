import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/depot.dart';
import '../pages/appro/index.dart';
import '../pages/client/index.dart';
import '../pages/depot/dashboard.dart';
import '../pages/depot/index.dart';
import '../pages/reservation/index.dart';
import '../pages/reservation/show.dart';
import '../pages/transfert/index.dart';
import '../pages/vente/compassassion_create.dart';
import '../pages/vente/compassassion_index.dart';
import '../pages/vente/index.dart';
import '../pages/vente/show.dart';
import 'constants.dart';

/// Snapshot de navigation persisté tant que la session JWT est active.
class NavSnapshot {
  const NavSnapshot({
    required this.screen,
    this.depotId,
    this.entityId,
    this.navIndex = 0,
  });

  final String screen;
  final int? depotId;
  final int? entityId;
  final int navIndex;

  Map<String, dynamic> toJson() => {
        'screen': screen,
        'depotId': depotId,
        'entityId': entityId,
        'navIndex': navIndex,
      };

  factory NavSnapshot.fromJson(Map<String, dynamic> json) {
    return NavSnapshot(
      screen: json['screen']?.toString() ?? 'dashboard',
      depotId: json['depotId'] is int
          ? json['depotId'] as int
          : int.tryParse('${json['depotId'] ?? ''}'),
      entityId: json['entityId'] is int
          ? json['entityId'] as int
          : int.tryParse('${json['entityId'] ?? ''}'),
      navIndex: json['navIndex'] is int
          ? json['navIndex'] as int
          : int.tryParse('${json['navIndex'] ?? 0}') ?? 0,
    );
  }
}

/// Sauvegarde / restauration de l’écran courant (cold start avec session).
class NavRestore {
  NavRestore._();

  static const dashboard = 'dashboard';
  static const depotList = 'depot_list';
  static const ventes = 'ventes';
  static const venteShow = 'vente_show';
  static const compassassionCreate = 'compassassion_create';
  static const compassassions = 'compassassions';
  static const reservations = 'reservations';
  static const reservationShow = 'reservation_show';
  static const appros = 'appros';
  static const transferts = 'transferts';
  static const clients = 'clients';

  static Future<void> save({
    required String screen,
    int? depotId,
    int? entityId,
    int navIndex = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final snap = NavSnapshot(
      screen: screen,
      depotId: depotId,
      entityId: entityId,
      navIndex: navIndex,
    );
    await prefs.setString(storageNavRestoreKey, jsonEncode(snap.toJson()));
  }

  static Future<NavSnapshot?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageNavRestoreKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return NavSnapshot.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageNavRestoreKey);
  }

  /// Accueil post-login : dashboard / liste PDV, puis pousse l’écran mémorisé.
  static Widget homeFor(List<Depot> depots, {NavSnapshot? snap}) {
    if (depots.isEmpty) return DepotListPage(depots: depots);

    final target = snap;
    if (target == null || target.screen == depotList) {
      if (depots.length == 1) {
        return DashboardPage(depot: depots.first);
      }
      return DepotListPage(depots: depots);
    }

    Depot? depot;
    if (target.depotId != null) {
      for (final d in depots) {
        if (d.id == target.depotId) {
          depot = d;
          break;
        }
      }
    }
    depot ??= depots.length == 1 ? depots.first : null;
    if (depot == null) {
      return DepotListPage(depots: depots);
    }

    if (target.screen == dashboard) {
      return DashboardPage(depot: depot, initialNavIndex: target.navIndex);
    }

    return _RestoringHome(depot: depot, snap: target);
  }
}

/// Dashboard d’abord, puis push de l’écran mémorisé après le 1er frame.
class _RestoringHome extends StatefulWidget {
  const _RestoringHome({
    required this.depot,
    required this.snap,
  });

  final Depot depot;
  final NavSnapshot snap;

  @override
  State<_RestoringHome> createState() => _RestoringHomeState();
}

class _RestoringHomeState extends State<_RestoringHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pushRestored());
  }

  Future<void> _pushRestored() async {
    if (!mounted) return;
    final depot = widget.depot;
    final snap = widget.snap;
    final page = _pageFor(snap, depot);
    if (page == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget? _pageFor(NavSnapshot snap, Depot depot) {
    switch (snap.screen) {
      case NavRestore.ventes:
        return VenteIndexPage(depot: depot);
      case NavRestore.venteShow:
        if (snap.entityId != null && snap.entityId! > 0) {
          return VenteShowPage(venteId: snap.entityId!, depot: depot);
        }
        return VenteIndexPage(depot: depot);
      case NavRestore.compassassionCreate:
        if (snap.entityId != null && snap.entityId! > 0) {
          return CompassassionCreatePage(
            venteId: snap.entityId!,
            depot: depot,
          );
        }
        return null;
      case NavRestore.compassassions:
        return CompassassionIndexPage(depot: depot);
      case NavRestore.reservations:
        return ReservationIndexPage(depot: depot);
      case NavRestore.reservationShow:
        if (snap.entityId != null && snap.entityId! > 0) {
          return ReservationShowPage(
            reservationId: snap.entityId!,
            depot: depot,
          );
        }
        return ReservationIndexPage(depot: depot);
      case NavRestore.appros:
        return ApproIndexPage(depot: depot);
      case NavRestore.transferts:
        return TransfertIndexPage(depot: depot);
      case NavRestore.clients:
        return ClientIndexPage(depot: depot);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(depot: widget.depot);
  }
}
