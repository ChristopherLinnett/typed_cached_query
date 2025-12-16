class ValidationError extends Error {
  final Map<String, List<String>> fieldErrors;

  ValidationError(this.fieldErrors);

  @override
  String toString() => 'ValidationError: $fieldErrors';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValidationError && fieldErrors.toString() == other.fieldErrors.toString();
  }

  @override
  int get hashCode => fieldErrors.toString().hashCode;
}
