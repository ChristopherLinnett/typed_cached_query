import 'package:cached_query_flutter/cached_query_flutter.dart';

/// Builds the [QueryConfig] a `Query` or `InfiniteQuery` is constructed with: the caller's [config] completed by the
/// cache's [global] config, with the storage behaviour the request itself declares laid over the top.
///
/// The merge happens on the caller's config as given. A [QueryConfig] getter resolves an unset field to the library
/// default rather than to `null`, so reading the fields back out before merging would make every unset field look
/// set, and the global config — and any field added to [QueryConfig] later, as `retryConfig` was — would never apply.
///
/// [owner] names the key in the error thrown when a request asks to be stored without saying how to serialize itself.
QueryConfig<Data> buildQueryConfig<Data>({
  required QueryConfig<Data>? config,
  required GlobalQueryConfig global,
  required bool storeQuery,
  required Map<String, dynamic> Function(Data)? storageSerializer,
  required Data Function(Map<String, dynamic>)? storageDeserializer,
  required String owner,
}) {
  if (config != null && storeQuery && storageSerializer == null) {
    throw ArgumentError('storageSerializer must be provided when using storeQuery in QueryConfig for $owner.');
  }
  final merged = (config ?? QueryConfig<Data>()).mergeWithGlobal(global);
  return QueryConfig<Data>(
    storageSerializer: storageSerializer,
    storageDeserializer: storageSerializer == null ? null : (map) => storageDeserializer!(map as Map<String, dynamic>),
    storeQuery: storeQuery,
    shouldFetch: merged.shouldFetch,
    storageDuration: merged.storageDuration,
    pollingInterval: merged.pollingInterval,
    pollInactive: merged.pollInactive,
    ignoreCacheDuration: merged.ignoreCacheDuration,
    staleDuration: merged.staleDuration,
    cacheDuration: merged.cacheDuration,
    shouldRethrow: merged.shouldRethrow,
    refetchOnResume: merged.refetchOnResume,
    refetchOnConnection: merged.refetchOnConnection,
    retryConfig: merged.retryConfig,
  );
}
