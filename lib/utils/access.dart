import '../api/auth_service.dart';
import '../models/depot.dart';
import '../models/user.dart';
import 'methode.dart';

/// Droits alignés sur les vues Blade (`sidebar`, `dashboard`, `actionLink`, `hearder`).
///
/// Rôles : `user` | `Administrateur` | `Super admin`.
class Access {
  Access({this.role, this.user});

  final Role? role;
  final User? user;

  static const adminRoles = ['Administrateur', 'Super admin'];

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

  /// Dépôts affichés comme `dashboard.blade.php` :
  /// Super admin → tous ; Administrateur → `user.depot` ;
  /// sinon → `user.depotUser.depot` (affectations du user connecté).
  List<Depot> visibleDepots([List<Depot> allFromApi = const []]) {
    if (isSuperAdmin) return allFromApi;
    if (isAdministrateur) {
      final owned = user?.depot ?? [];
      if (owned.isNotEmpty) return owned;
      return allFromApi.where((d) => user != null && d.userId == user!.id).toList();
    }
    return user?.assignedDepots(allFromApi) ?? [];
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
