/// Convertit un tableau JSON en liste de maps (ignore les éléments non-objets).
List<Map<String, dynamic>?> convertJsonArrayToMapList(List<dynamic> jsonArray) {
  return jsonArray.map((item) {
    if (item is Map<String, dynamic>) {
      return item;
    }
    return null;
  }).toList();
}

/// Parse un entier API (int, num ou String).
int asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

/// Parse un double API (double, int ou String). `null` si absent / invalide.
double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

DateTime? asDateTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return null;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic>? asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}
