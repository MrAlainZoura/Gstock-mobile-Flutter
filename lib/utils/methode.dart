// import 'dart:convert';

List<Map<String, dynamic>?> convertJsonArrayToMapList(List<dynamic> jsonArray) {
  return jsonArray.map((item) {
    if (item is Map<String, dynamic>) {
      return item;
    } else {
      return null;
      // throw Exception("L'élément n'est pas un Map<String, dynamic>: $item");
    }
  }).toList();
}