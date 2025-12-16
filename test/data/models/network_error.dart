class NetworkError extends Error {
  final String reason;
  final bool isRetryable;

  NetworkError(this.reason, {this.isRetryable = true});

  @override
  String toString() => 'NetworkError: $reason';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NetworkError && other.reason == reason && other.isRetryable == isRetryable;
  }

  @override
  int get hashCode => reason.hashCode ^ isRetryable.hashCode;
}
