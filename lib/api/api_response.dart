/// Enveloppe JSON standard de l'API GStock :
/// `{ "success": true, "message": "OK", "data": ... }`
///
/// Exceptions :
/// - `POST /auth/login` n'utilise pas cette enveloppe (token à la racine).
/// - certains `apiResource` historiques (`users`, `depots`, `produits`…)
///   peuvent omettre `message` ou renvoyer uniquement les erreurs de validation.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final dynamic errors;

  @override
  String toString() => message;
}

class ApiResponse<T> {
  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.errors,
    this.statusCode,
  });

  final bool success;
  final String? message;
  final T? data;
  final dynamic errors;
  final int? statusCode;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    T Function(dynamic raw)? parse,
    int? statusCode,
  }) {
    return ApiResponse(
      success: json['success'] == true,
      message: json['message'] as String?,
      data: json['data'] == null || parse == null
          ? json['data'] as T?
          : parse(json['data']),
      errors: json['errors'] ?? json['error'],
      statusCode: statusCode,
    );
  }

  /// Extrait `data` ou lève [ApiException] si `success != true`.
  T requireData({String fallbackMessage = 'Erreur API'}) {
    if (!success) {
      throw ApiException(
        message ?? fallbackMessage,
        statusCode: statusCode,
        errors: errors,
      );
    }
    if (data == null) {
      throw ApiException(fallbackMessage, statusCode: statusCode);
    }
    return data as T;
  }
}
