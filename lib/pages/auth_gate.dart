import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../api/dashboard_service.dart';
import '../models/depot.dart';
import '../utils/access.dart';
import '../utils/app_theme.dart';
import 'depot/dashboard.dart';
import 'depot/index.dart';
import 'login_page.dart';

/// Au démarrage : session JWT valide → dashboard / points de vente ;
/// sinon → [LoginPage].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final auth = AuthService();
    final token = await auth.getToken();
    if (token == null || token.isEmpty) {
      _goLogin();
      return;
    }

    try {
      final sessionUser = await auth.me();
      final role = await auth.role();
      final dash = await DashboardService().getDashboard();
      final connected = dash.user ?? sessionUser;
      final access = Access(role: role, user: connected);
      final depots = access.visibleDepots(dash.depots);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => postLoginHome(depots)),
      );
    } catch (_) {
      await auth.logout();
      _goLogin();
    }
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.black,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.white),
      ),
    );
  }
}

/// Une seule PDV → dashboard ; plusieurs → liste des points de vente.
Widget postLoginHome(List<Depot> depots) {
  if (depots.length == 1) {
    return DashboardPage(depot: depots.first);
  }
  return DepotListPage(depots: depots);
}
