/// Durée calendaire harmonisée :
/// `1h30`, `1j`, `1mois 4jrs 3h 20min`.
String formatPeriode(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '—';
  var from = start;
  var to = end;
  if (to.isBefore(from)) {
    final tmp = from;
    from = to;
    to = tmp;
  }

  var years = to.year - from.year;
  var months = to.month - from.month;
  var days = to.day - from.day;
  var hours = to.hour - from.hour;
  var minutes = to.minute - from.minute;

  if (minutes < 0) {
    minutes += 60;
    hours--;
  }
  if (hours < 0) {
    hours += 24;
    days--;
  }
  if (days < 0) {
    final previousMonth = DateTime(to.year, to.month, 0);
    days += previousMonth.day;
    months--;
  }
  if (months < 0) {
    months += 12;
    years--;
  }

  if (years == 0 && months == 0 && days == 0) {
    if (hours > 0 && minutes > 0) {
      return '${hours}h${minutes.toString().padLeft(2, '0')}';
    }
    if (hours > 0) return '${hours}h';
    return '${minutes}min';
  }

  final parts = <String>[];
  if (years > 0) parts.add(years == 1 ? '1an' : '${years}ans');
  if (months > 0) parts.add('${months}mois');
  if (days > 0) parts.add(days == 1 ? '1j' : '${days}jrs');
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0) parts.add('${minutes}min');
  return parts.isEmpty ? '0min' : parts.join(' ');
}

String formatDateTimeFr(DateTime? value) {
  if (value == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}
