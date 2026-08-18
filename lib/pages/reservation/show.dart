import 'package:flutter/material.dart';

import '../../api/api_response.dart';
import '../../api/reservation_service.dart';
import '../../models/reservation.dart';
import '../../models/vente.dart';
import '../../utils/access.dart';
import '../../utils/app_theme.dart';
import '../../utils/duree.dart';
import '../../widgets/confirm_dialog.dart';

/// Détail `GET /reservations/{id}` + paiement créance.
class ReservationShowPage extends StatefulWidget {
  const ReservationShowPage({super.key, required this.reservationId});

  final int reservationId;

  @override
  State<ReservationShowPage> createState() => _ReservationShowPageState();
}

class _ReservationShowPageState extends State<ReservationShowPage> {
  final _paiment = TextEditingController();
  bool _paying = false;
  bool _loading = true;
  String? _error;
  Reservation? _reservation;
  Access _access = Access();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paiment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ReservationService().getById(widget.reservationId),
        Access.load(),
      ]);
      if (!mounted) return;
      setState(() {
        _reservation = results[0] as Reservation;
        _access = results[1] as Access;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _payer() async {
    final montant = num.tryParse(_paiment.text.trim().replaceAll(' ', ''));
    if (montant == null) return;
    setState(() => _paying = true);
    try {
      await ReservationService().payerCreance(widget.reservationId, montant);
      if (!mounted) return;
      _paiment.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Paiement enregistré")));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _delete() async {
    if (!_access.canDeleteReservation) return;
    final ok = await confirmAction(
      context,
      title: 'Supprimer cette réservation ?',
      message:
          'La réservation sera envoyée à la corbeille. Cette action est réservée aux administrateurs.',
    );
    if (!ok || !mounted) return;
    try {
      await ReservationService().delete(widget.reservationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Réservation supprimée (corbeille)")),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservation = _reservation;
    return Scaffold(
      backgroundColor: AppColors.grayLight,
      appBar: AppBar(
        title: Text(
          reservation == null
              ? "Détail réservation"
              : (reservation.code.isEmpty
                    ? "Réservation #${reservation.id}"
                    : reservation.code),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text("Erreur: $_error"))
          : reservation == null
          ? const Center(child: Text("Réservation introuvable"))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _InfoCard(
                    children: [
                      _kv("Client", reservation.clientName),
                      _kv("Facturé par", reservation.vendorName),
                      if (reservation.statut.isNotEmpty)
                        _kv("Statut", reservation.statut),
                      _kv(
                        "Taux de change",
                        "1 ${reservation.deviseLibele} = ${formatMoney(reservation.taux)} CDF",
                      ),
                      _kv("Début", formatDateTimeFr(reservation.dateDebut)),
                      _kv("Fin", formatDateTimeFr(reservation.dateFin)),
                      _kv("Période", reservation.periode),
                      if (reservation.createdAt != null)
                        _kv(
                          "Créée le",
                          formatDateTimeFr(reservation.createdAt),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProductsCard(reservation: reservation),
                  const SizedBox(height: 12),
                  _TotalsCard(reservation: reservation),
                  if (reservation.reste > 0) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Encaisser le reste (créance)",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _paiment,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    "Montant (${reservation.deviseLibele})",
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _paying ? null : _payer,
                              child: const Text("Payer"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_access.canDeleteReservation) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                      ),
                      onPressed: _delete,
                      icon: const Icon(Icons.delete),
                      label: const Text("Supprimer"),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.gray)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _ProductsCard extends StatelessWidget {
  const _ProductsCard({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Produits",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (reservation.lignes.isEmpty)
              const Text(
                "Aucun produit",
                style: TextStyle(color: AppColors.gray),
              )
            else
              ...reservation.lignes.map((l) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.libele,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Début ${formatDateTimeFr(l.debut)}",
                        style: const TextStyle(color: AppColors.gray),
                      ),
                      Text(
                        "Fin ${formatDateTimeFr(l.fin)}",
                        style: const TextStyle(color: AppColors.gray),
                      ),
                      Text(
                        "Période ${l.periode}",
                        style: const TextStyle(color: AppColors.gray),
                      ),
                      Text(
                        "Total ${reservation.moneyLabel(l.montant)}",
                        style: const TextStyle(color: AppColors.gray),
                      ),
                      if (l.reduction > 0)
                        Text(
                          "Réduction ${reservation.moneyLabel(l.reduction)}",
                          style: const TextStyle(color: AppColors.gray),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(
              "Net à payer",
              reservation.moneyLabel(reservation.netAPayer),
              bold: true,
            ),
            _row(
              "Paiement reçu",
              reservation.moneyLabel(reservation.paiementRecu),
            ),
            if (reservation.isTranche)
              _row(
                "Reste (tranche)",
                reservation.moneyLabel(reservation.reste),
                valueColor: reservation.reste > 0
                    ? AppColors.red
                    : AppColors.black,
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.gray,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: valueColor ?? AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
