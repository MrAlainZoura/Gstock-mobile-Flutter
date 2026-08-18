class RankingItem {
  RankingItem({required this.name, required this.value, this.detail = ''});

  final String name;
  final num value;
  final String detail;
}

/// Stats du mois courant (`GET /rapports/depot/{depot}/mensuel`).
class MonthlyRapport {
  MonthlyRapport({
    required this.label,
    required this.periodLabel,
    required this.ventesCount,
    required this.transfertsCount,
    required this.approCount,
    required this.reservationsCount,
    required this.topVendeurs,
    required this.topProduitsVendus,
    required this.topProduitsReserves,
  });

  final String label;
  final String periodLabel;
  final int ventesCount;
  final int transfertsCount;
  final int approCount;
  final int reservationsCount;
  final List<RankingItem> topVendeurs;
  final List<RankingItem> topProduitsVendus;
  final List<RankingItem> topProduitsReserves;
}
