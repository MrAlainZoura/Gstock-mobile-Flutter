import 'package:flutter/material.dart';

import 'app_theme.dart';

enum PeriodPreset { today, week, month, custom }

class PeriodRange {
  PeriodRange({
    required this.preset,
    required this.from,
    required this.to,
  });

  final PeriodPreset preset;
  final DateTime from;
  final DateTime to;

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  factory PeriodRange.today() {
    final now = DateTime.now();
    return PeriodRange(
      preset: PeriodPreset.today,
      from: dayStart(now),
      to: dayEnd(now),
    );
  }

  factory PeriodRange.week() {
    final now = DateTime.now();
    return PeriodRange(
      preset: PeriodPreset.week,
      from: dayStart(now.subtract(const Duration(days: 6))),
      to: dayEnd(now),
    );
  }

  factory PeriodRange.month() {
    final now = DateTime.now();
    return PeriodRange(
      preset: PeriodPreset.month,
      from: DateTime(now.year, now.month, 1),
      to: dayEnd(now),
    );
  }

  factory PeriodRange.custom(DateTime start, DateTime end) {
    final a = dayStart(start);
    final b = dayEnd(end);
    return a.isAfter(b)
        ? PeriodRange(preset: PeriodPreset.custom, from: dayStart(end), to: dayEnd(start))
        : PeriodRange(preset: PeriodPreset.custom, from: a, to: b);
  }

  String get fromParam => ymd(from);
  String get toParam => ymd(to);

  bool contains(DateTime? date) {
    if (date == null) return false;
    return !date.isBefore(from) && !date.isAfter(to);
  }
}

String ymd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

String dmy(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$day/$m/${d.year}';
}

class PeriodFilterBar extends StatelessWidget {
  const PeriodFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PeriodRange value;
  final ValueChanged<PeriodRange> onChanged;

  Future<void> _pickCustom(BuildContext context) async {
    final start = await showDatePicker(
      context: context,
      initialDate: value.from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Date de début',
    );
    if (start == null || !context.mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: value.to.isBefore(start) ? start : value.to,
      firstDate: start,
      lastDate: DateTime.now(),
      helpText: 'Date de fin',
    );
    if (end == null || !context.mounted) return;
    onChanged(PeriodRange.custom(start, end));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(
              label: "Aujourd'hui",
              selected: value.preset == PeriodPreset.today,
              onTap: () => onChanged(PeriodRange.today()),
            ),
            _chip(
              label: 'Semaine',
              selected: value.preset == PeriodPreset.week,
              onTap: () => onChanged(PeriodRange.week()),
            ),
            _chip(
              label: 'Mois',
              selected: value.preset == PeriodPreset.month,
              onTap: () => onChanged(PeriodRange.month()),
            ),
            _chip(
              label: 'Période',
              selected: value.preset == PeriodPreset.custom,
              onTap: () => _pickCustom(context),
            ),
          ],
        ),
        if (value.preset == PeriodPreset.custom) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickCustom(context),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text('${dmy(value.from)} → ${dmy(value.to)}'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.blue,
      labelStyle: TextStyle(
        color: selected ? AppColors.white : AppColors.black,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.white,
      side: BorderSide(
        color: selected ? AppColors.blue : AppColors.gray.withValues(alpha: 0.4),
      ),
    );
  }
}
