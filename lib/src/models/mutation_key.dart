import 'dart:async';

import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/query_key.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

/// Default linear backoff used when no [backoff] is supplied: 100 ms × attempt.
/// `attempt` is 1-based — i.e. called with 1 between attempts 1 and 2, 2 between 2 and 3, etc.
Duration defaultMutationBackoff(int attempt) => Duration(milliseconds: 100 * attempt);

class MutationKey<RequestType extends MutationSerializable<RequestType, ReturnType, ErrorType>, ReturnType, ErrorType> {
  final RequestType request;
  MutationKey(this.request);

  String get _valueKey => request.keyGenerator;

  Mutation<ReturnType, RequestType> definition({
    void Function(RequestType, MutationException, ReturnType?)? onError,
    void Function(ReturnType, RequestType)? onSuccess,
    MutationCache? cache,
    FutureOr<ReturnType> Function(RequestType)? onStartMutation,
    List<QueryKey<dynamic, dynamic, dynamic>>? invalidateQueries,
    List<QueryKey<dynamic, dynamic, dynamic>>? refetchQueries,
    int? retryAttempts,
    bool Function(ErrorType)? shouldRetry,
    int? timeoutSeconds,
    void Function(RequestType)? onTimeout,
    Duration Function(int attempt)? backoff,
  }) {
    if ((retryAttempts == null) != (shouldRetry == null)) throw ArgumentError('Either provide both retryAttempts and shouldRetry, or neither.');

    /// Recommended to provide onTimeout to handle timeout errors gracefully.
    /// If [timeoutSeconds] is provided without [onTimeout], your mutationFn should handle and convert a TimeoutException to [ErrorType]
    if (onTimeout != null && timeoutSeconds == null) throw ArgumentError('If onTimeout is provided, timeoutSeconds must also be provided.');

    // Explicitly capture the onTimeout parameter to avoid closure capture issues
    final capturedOnTimeout = onTimeout;
    final backoffFn = backoff ?? defaultMutationBackoff;

    return Mutation<ReturnType, RequestType>(
      key: _valueKey,
      mutationFn: (requestParam) async {
        final maxAttempts = (retryAttempts ?? 0) + 1;
        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            return timeoutSeconds != null
                ? await request.mutationFn().timeout(Duration(seconds: timeoutSeconds))
                : await request.mutationFn();
          } catch (e) {
            if (e is TimeoutException && capturedOnTimeout != null) rethrow;
            if (e is! ErrorType) {
              throw MutationException(
                'An unhandled exception has taken place, please update your definitions for ${request.runtimeType} to include this error, error: ${e.toString()}',
                500,
              );
            }
            final canRetry = shouldRetry != null && attempt < maxAttempts && shouldRetry(e as ErrorType);
            if (!canRetry) rethrow;
            await Future<void>.delayed(backoffFn(attempt));
          }
        }
        // Unreachable: the loop body always exits via `return` or `rethrow` on the final attempt.
        // Dart's flow analysis does not see this, so a terminator is required.
        throw StateError('unreachable: mutation retry loop completed without returning or throwing');
      },
      onError: (requestParam, error, fallback) {
        if (error is MutationException || error is ArgumentError) {
          throw error;
        }
        if (error is TimeoutException && capturedOnTimeout != null) {
          capturedOnTimeout(request);
          return; // Don't return the void result, just handle the timeout
        }

        final onErrorResults = request.errorMapper(request, error as ErrorType, fallback as ReturnType?);
        onError?.call(onErrorResults.request, onErrorResults.error, onErrorResults.fallback);
      },
      onSuccess: onSuccess,
      cache: cache ?? request.cache,
      onStartMutation: onStartMutation,
      invalidateQueries: invalidateQueries?.map((queryKey) => queryKey.rawKey).toList(),
      refetchQueries: refetchQueries?.map((queryKey) => queryKey.rawKey).toList(),
    );
  }

  MutationCache get _cache => request.cache ?? MutationCache.instance;
  Mutation<ReturnType, RequestType>? get _getMutation => _cache.getMutation(_valueKey);
  bool get exists => _getMutation != null;
  bool get isMutating => _cache.contains(_valueKey);

  Future<MutationState<ReturnType?>> mutate({
    void Function(RequestType, MutationException, ReturnType?)? onError,
    void Function(ReturnType, RequestType)? onSuccess,
    MutationCache? cache,
    FutureOr<ReturnType> Function(RequestType)? onStartMutation,
    List<QueryKey<dynamic, dynamic, dynamic>>? invalidateQueries,
    List<QueryKey<dynamic, dynamic, dynamic>>? refetchQueries,
    int? retryAttempts,
    bool Function(ErrorType)? shouldRetry,
    int? timeoutSeconds,
    void Function(RequestType)? onTimeout,
    Duration Function(int attempt)? backoff,
  }) => definition(
    onError: onError,
    onSuccess: onSuccess,
    cache: cache,
    onStartMutation: onStartMutation,
    invalidateQueries: invalidateQueries,
    refetchQueries: refetchQueries,
    retryAttempts: retryAttempts,
    shouldRetry: shouldRetry,
    timeoutSeconds: timeoutSeconds,
    onTimeout: onTimeout,
    backoff: backoff,
  ).mutate(request);

  bool get isPending => _getMutation != null && _getMutation!.state.isLoading && _getMutation!.state.data == null;

  bool get isRefetching => _getMutation != null && _getMutation!.state.isLoading && _getMutation!.state.data != null;

  bool get isError => _getMutation != null && _getMutation!.state.isError;

  MutationException? get error {
    if (_getMutation == null) return null;
    final state = _getMutation!.state;
    if (state is! MutationError) return null;
    final stateError = state.error;
    if (stateError is MutationException) return stateError;
    if (stateError is ErrorType) return request.errorMapper(request, stateError, null).error;
    return MutationException('Unhandled error: $stateError', 500);
  }
}
