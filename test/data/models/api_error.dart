class ApiError extends Error {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? details;

  ApiError(this.message, this.statusCode, [this.details]);

  @override
  String toString() => 'ApiError($statusCode): $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiError && other.message == message && other.statusCode == statusCode;
  }

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode;
}
