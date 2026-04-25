import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

class QueryKey<RequestType extends QuerySerializable<ReturnType, ErrorType>, ReturnType, ErrorType> {
  final RequestType request;
  QueryKey(this.request);
  String get _valueKey => request.keyGenerator;
  String get rawKey => _valueKey;
  CachedQuery get _cache => request.cache ?? CachedQuery.instance;

  Query<ReturnType> query({
    void Function(QueryException)? onError,
    void Function(ReturnType)? onSuccess,
    QueryConfig<ReturnType>? config,
    CachedQuery? cache,
  }) {
    final queryCache = cache ?? request.cache ?? CachedQuery.instance;
    _validateConfig(config);
    return Query(
      key: _valueKey,
      queryFn: _wrappedQueryFn,
      onError: _wrappedOnError(onError),
      onSuccess: onSuccess,
      config: _buildConfig(config, queryCache),
      cache: queryCache,
    );
  }

  void _validateConfig(QueryConfig<ReturnType>? config) {
    if (config != null && request.storeQuery && request.storageSerializer == null) {
      throw ArgumentError(
        'storageSerializer must be provided when using storeQuery in QueryConfig for QueryKey<$RequestType, $ReturnType, $ErrorType>.',
      );
    }
  }

  Future<ReturnType> _wrappedQueryFn() async {
    dynamic rawResponse;
    try {
      rawResponse = await request.queryFn();
    } catch (e) {
      if (e is ErrorType) rethrow;
      throw QueryException(
        'An unhandled exception has taken place, please update your definitions to include this error, error: ${e.toString()}',
        500,
      );
    }
    try {
      return request.responseHandler(rawResponse);
    } catch (e) {
      throw QueryException('parsing the response of type ${rawResponse.runtimeType} to $ReturnType failed: ${e.toString()}', 400);
    }
  }

  void Function(dynamic) _wrappedOnError(void Function(QueryException)? userOnError) {
    return (error) {
      if (error is QueryException) {
        userOnError?.call(error);
        return;
      }
      if (error is ErrorType) {
        userOnError?.call(request.errorMapper(error));
        return;
      }
      userOnError?.call(QueryException('An unhandled exception occurred: ${error.toString()}', 500));
    };
  }

  QueryConfig<ReturnType> _buildConfig(QueryConfig<ReturnType>? config, CachedQuery queryCache) {
    return QueryConfig<ReturnType>(
      storageSerializer: request.storageSerializer,
      storageDeserializer: request.storageSerializer == null ? null : (map) => request.storageDeserializer!(map as Map<String, dynamic>),
      storeQuery: request.storeQuery,
      shouldFetch: config?.shouldFetch,
      storageDuration: config?.storageDuration,
      pollingInterval: config?.pollingInterval,
      pollInactive: config?.pollInactive ?? false,
      ignoreCacheDuration: config?.ignoreCacheDuration,
      staleDuration: config?.staleDuration,
      cacheDuration: config?.cacheDuration,
      shouldRethrow: config?.shouldRethrow,
      refetchOnResume: config?.refetchOnResume,
      refetchOnConnection: config?.refetchOnConnection,
    ).mergeWithGlobal(queryCache.defaultConfig);
  }

  Cacheable<QueryStatus<ReturnType>>? get _getQuery => _cache.getQuery(_valueKey);

  bool get exists => _getQuery != null;
  bool get isPending => _getQuery != null && _getQuery!.state.isLoading && _getQuery!.state.data == null;
  bool get isRefetching => _getQuery != null && _getQuery!.state.isLoading && _getQuery!.state.data != null;
  bool get isError => _getQuery != null && _getQuery!.state.isError;
  QueryException? get error {
    if (_getQuery == null) return null;
    final stateError = _getQuery!.state.error;
    if (stateError == null) return null;
    if (stateError is QueryException) return stateError;
    if (stateError is ErrorType) return request.errorMapper(stateError);
    return QueryException('Unhandled error: $stateError', 500);
  }

  T updateData<T>(T Function(ReturnType? existingData) updateFunction) {
    if (_getQuery == null) {
      final initial = updateFunction(null);
      _cache.setQueryData(key: _valueKey, data: initial);
      return initial;
    }
    final next = updateFunction(_getQuery!.state.data);
    _cache.updateQuery(key: _valueKey, updateFn: (_) => next);
    return next;
  }

  void invalidate({bool refetchActive = true, bool refetchInactive = false}) {
    _getQuery?.invalidate(refetchActive: refetchActive, refetchInactive: refetchInactive);
  }

  Future<QueryStatus<ReturnType>?> Function() get fetch {
    return () async {
      if (_getQuery == null) return Future.value(null);
      return _getQuery?.fetch();
    };
  }
}
