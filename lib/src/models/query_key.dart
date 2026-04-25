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
    if (config != null && request.storeQuery && request.storageSerializer == null) {
      throw ArgumentError(
        'storageSerializer must be provided when using storeQuery in QueryConfig for QueryKey<$RequestType, $ReturnType, $ErrorType>.',
      );
    }
    return Query(
      key: _valueKey,
      queryFn: () {
        try {
          return request.queryFn().then((response) {
            try {
              return request.responseHandler(response);
            } catch (e) {
              throw FormatException('parsing the response of type ${response.runtimeType} to $ReturnType failed: ${e.toString()}');
            }
          });
        } catch (e) {
          if (e is ErrorType) rethrow;
          if (e is FormatException) throw QueryException(e.message, 400);

          /// Will always be caught by th onError handler in the query and stop execution.
          /// Recommend to always finish the query function by throwing any unpredicted errors as [ErrorType].
          throw QueryException(
            'An unhandled exception has taken place, please update your definitions to include this error, error: ${e.toString()}',
            500,
          );
        }
      },
      onError: (error) => error is QueryException
          /// if the error is not handled, it will throw as QueryException with generic message and error contents turned as [String].
          ? throw error
          : onError?.call(request.errorMapper(error as ErrorType)),
      onSuccess: onSuccess,
      config: QueryConfig(
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
      ).mergeWithGlobal(queryCache.defaultConfig),
      cache: cache ?? request.cache ?? CachedQuery.instance,
    );
  }

  Cacheable<QueryStatus<ReturnType>>? get _getQuery => _cache.getQuery(_valueKey);

  bool get exists => _getQuery != null;
  bool get isPending => _getQuery != null && _getQuery!.state.isLoading && _getQuery!.state.data == null;
  bool get isRefetching => _getQuery != null && _getQuery!.state.isLoading && _getQuery!.state.data != null;
  bool get isError => _getQuery != null && _getQuery!.state.isError;
  QueryException? get error => _getQuery == null || !_getQuery!.state.isError ? null : request.errorMapper(_getQuery!.state.error! as ErrorType);

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
