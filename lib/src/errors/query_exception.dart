class QueryException implements Exception {
  final String message;
  final int statusCode;

  QueryException(this.message, this.statusCode);

  @override
  String toString() => '$runtimeType: $message (Status Code: $statusCode)';

  @override
  bool operator ==(Object other) => identical(this, other) || other is QueryException && message == other.message && statusCode == other.statusCode;

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode;
}

class MutationException implements Exception {
  final String message;
  final int statusCode;

  MutationException(this.message, this.statusCode);

  @override
  String toString() => '$runtimeType: $message (Status Code: $statusCode)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MutationException && message == other.message && statusCode == other.statusCode;

  @override
  int get hashCode => message.hashCode ^ statusCode.hashCode;
}
