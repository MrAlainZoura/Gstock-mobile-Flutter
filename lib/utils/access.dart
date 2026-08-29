import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../models/depot.dart';
import '../models/user.dart';
import 'app_theme.dart';
import 'methode.dart';

/// Droits alignés sur les vues Blade (`sidebar`, `dashboard`, `actionLink`, `hearder`).
///
/// Rôles : `user` | `Administrateur` | `Super admin`.
class Access {
  Access({this.role, this.user});

  final Role? role;
  final User? user;

  static const adminRoles = ['Administrateur', 'Super admin'];

  static const subscriptionInactiveMessage =
      "Abonnement inactif : créez / modifiez impossible. "
      "Consultation limitée au mois en cours.";

  static Future<Access> load() async {
    final auth = AuthService();
    return Access(role: await auth.role(), user: await auth.user());
  }

  String get libele =>
      role?.libele ?? user?.userRole?.role?.libele ?? 'user';

  bool get isAdmin => adminRoles.contains(libele);
  bool get isSuperAdmin => libele == 'Super admin';
  bool get isAdministrateur => libele == 'Administrateur';
  bool get isSimpleUser => libele == 'user';

  /// Points de vente visibles :
  /// Super admin → tous ; Administrateur → ses PDV (`user.depot`)
  /// + ceux où il est affecté (`depotUser`) ; sinon → affectations seules.
  List<Depot> visibleDepots([List<Depot> allFromApi = const []]) {
    if (isSuperAdmin) return allFromApi;
    if (isAdministrateur) {
      final byId = <int, Depot>{};
      for (final d in user?.depot ?? const <Depot>[]) {
        byId[d.id] = d;
      }
      for (final d in user?.assignedDepots(allFromApi) ?? const <Depot>[]) {
        byId[d.id] = d;
      }
      if (byId.isEmpty && user != null) {
        for (final d in allFromApi.where((d) => d.userId == user!.id)) {
          byId[d.id] = d;
        }
      }
      return byId.values.toList();
    }
    return user?.assignedDepots(allFromApi) ?? [];
  }

  /// `Depot::abonnementCurrent()` — Super admin toujours actif.
  bool abonnementCurrent([Depot? depot]) {
    if (isSuperAdmin) return true;
    return depot?.abonnementCurrent ?? true;
  }

  /// Create / PUT autorisés uniquement si abonnement courant.
  bool canWrite([Depot? depot]) => abonnementCurrent(depot);

  /// GET limité au mois en cours si abonnement inactif.
  bool getPeriodLockedToMonth([Depot? depot]) => !abonnementCurrent(depot);

  void showSubscriptionBlocked(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.red,
        content: Text(subscriptionInactiveMessage),
      ),
    );
  }

  /// `Depot+` (header dashboard) : Super admin toujours ;
  /// Administrateur si `depot.count <= maxDepot()` (abonnement, défaut 1).
  bool get canCreateDepot {
    if (isSuperAdmin) return true;
    if (!isAdministrateur) return false;
    final owned = user?.depot?.length ?? 0;
    return owned <= user.maxDepot;
  }

  /// Sidebar : Mise à jour / Paramètres dépôt.
  bool get canEditDepot => isAdmin;

  /// Sidebar : Catégorie + Ajouter produit.
  bool get canAddProduit => isAdmin;

  /// Sidebar : Ajouter utilisateur.
  bool get canCreateUser => isAdmin;

  /// Soft-delete compte : soi-même si rôle `user`, ou admin sur un `user`.
  bool canDeleteAccount(User target) {
    if (target.isDeleted) return false;
    final targetRole =
        target.userRole?.role?.libele ?? 'user';
    if (adminRoles.contains(targetRole)) return false;
    if (user != null && user!.id == target.id) return true;
    return isAdmin;
  }

  /// Profil Blade : soi-même **ou** admin.
  bool canEditUser(int targetUserId) =>
      isAdmin || (user != null && user!.id == targetUserId);

  /// `PUT .../password/reset` + Blade reset.
  bool get canResetPassword => isAdmin;

  /// Corbeille ventes / réservations / dépenses.
  bool get canSeeCorbeille => isAdmin;

  /// Suppression vente / dépense / réservation (show Blade).
  bool get canDeleteVente => isAdmin;
  bool get canDeleteDepense => isAdmin;
  bool get canDeleteReservation => isAdmin;

  /// Recette globale liste ventes.
  bool get canSeeRecette => isAdmin;

  /// Rapports journalier / mensuel / annuel.
  bool get canSeeRapports => isAdmin;

  /// Confirmer tout / supprimer un approvisionnement.
  bool get canConfirmAllAppro => isAdmin;
  bool get canDeleteAppro => isAdmin;

  /// Présence : confirmer / supprimer.
  bool get canConfirmPresence => isAdmin;

  /// Un `user` peut confirmer **son** approvisionnement (actionLink).
  bool get canConfirmOwnAppro => true;
}

extension UserAccessX on User? {
  /// `User::maxDepot()` : `souscription.latest.abonnement.max`, sinon 1.
  int get maxDepot {
    if (this == null) return 1;
    final subs = this!.souscription ?? [];
    int? max;
    for (final raw in subs) {
      final map = asMap(raw);
      final abo = asMap(map?['abonnement']);
      final value = asInt(abo?['max'], 0);
      if (value > 0) max = value;
    }
    return max ?? 1;
  }
}

extension UserDeletedX on User {
  bool get isDeleted => deletedAt != null;
}
