import 'package:flutter/material.dart';

/// Clé de navigation globale pour rediriger vers `/login` hors contexte widget.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

bool _redirectingToLogin = false;

/// Déconnexion locale + redirection login (token expiré / invalide).
Future<void> redirectToLoginOnSessionExpired() async {
  if (_redirectingToLogin) return;
  _redirectingToLogin = true;
  try {
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil('/login', (route) => false);
  } finally {
    // Laisse le temps à la stack de se reconstruire avant un nouvel appel.
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      _redirectingToLogin = false;
    });
  }
}
