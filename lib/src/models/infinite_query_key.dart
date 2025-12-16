import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

class InfiniteQueryKey<RequestType extends InfiniteQuerySerializable<ReturnType, RequestData, ErrorType>, ReturnType, RequestData, ErrorType> {
  final RequestType request;
  InfiniteQueryKey(this.request);

  String get _valueKey => request.keyGenerator();
  String get rawKey => _valueKey;
  CachedQuery get _cache => request.cache ?? CachedQuery.instance;

  InfiniteQuery<ReturnType, RequestData> query({
    void Function(QueryException)? onError,
    void Function(InfiniteQueryData<ReturnType, RequestData>)? onSuccess,
    QueryConfig<InfiniteQueryData<ReturnType, RequestData>>? config,
    CachedQuery? cache,
    int? prefetchPages,
    InfiniteQueryData<ReturnType, RequestData>? initialData,
  }) {
    final queryCache = cache ?? request.cache ?? CachedQuery.instance;
    if (config != null && request.storeQuery && request.storageSerializer == null) {
      throw ArgumentError(
        'storageSerializer must be provided when using storeQuery in QueryConfig for InfiniteQueryKey<$RequestType, $ReturnType, $RequestData, $ErrorType>.',
      );
    }

    return InfiniteQuery<ReturnType, RequestData>(
      key: _valueKey,
      queryFn: (RequestData arg) {
        try {
          return request.queryFn(arg);
        } catch (e) {
          if (e is ErrorType) rethrow;

          /// Will always be caught by the onError handler in the query and stop execution.
          /// Recommend to always finish the query function by throwing any unpredicted errors as [ErrorType].
          throw QueryException(
            'An unhandled exception has taken place, please update your definitions to include this error, error: ${e.toString()}',
            500,
          );
        }
      },
      getNextArg: (InfiniteQueryData<ReturnType, RequestData>? data) {
        try {
          return request.getNextArg(data);
        } catch (e) {
          if (e is ErrorType) {
            onError?.call(request.errorMapper(e as ErrorType));
          } else {
            onError?.call(QueryException('An unhandled exception occurred in getNextArg: ${e.toString()}', 500));
          }
          return null;
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
      prefetchPages: prefetchPages,
      initialData: initialData,
    );
  }

  Cacheable<InfiniteQueryStatus<ReturnType, RequestData>>? get _getInfiniteQuery => _cache.getQuery(_valueKey);

  bool get exists => _getInfiniteQuery != null;
  bool get isPending => _getInfiniteQuery != null && _getInfiniteQuery!.state.isLoading && _getInfiniteQuery!.state.data == null;
  bool get isRefetching => _getInfiniteQuery != null && _getInfiniteQuery!.state.isLoading && _getInfiniteQuery!.state.data != null;
  bool get isFetchingNextPage =>
      _getInfiniteQuery != null &&
      _getInfiniteQuery!.state is InfiniteQueryLoading &&
      (_getInfiniteQuery!.state as InfiniteQueryLoading).isFetchingNextPage;
  bool get isError => _getInfiniteQuery != null && _getInfiniteQuery!.state.isError;
  bool get hasReachedMax {
    if (_getInfiniteQuery == null) return false;

    // Use the InfiniteQuery's native hasReachedMax method
    if (_getInfiniteQuery is InfiniteQuery<ReturnType, RequestData>) {
      return (_getInfiniteQuery as InfiniteQuery<ReturnType, RequestData>).hasReachedMax();
    }

    // Fallback to checking the state
    return _getInfiniteQuery!.state is InfiniteQuerySuccess && (_getInfiniteQuery!.state as InfiniteQuerySuccess).hasReachedMax;
  }

  QueryException? get error =>
      _getInfiniteQuery == null || !_getInfiniteQuery!.state.isError ? null : request.errorMapper(_getInfiniteQuery!.state.error! as ErrorType);

  /// Get all pages as a flat list
  List<ReturnType> get allPages {
    final data = _getInfiniteQuery?.state.data;
    return data?.pages ?? [];
  }

  /// Get the arguments used for each page
  List<RequestData> get pageArgs {
    final data = _getInfiniteQuery?.state.data;
    return data?.args ?? [];
  }

  /// Update the infinite query data
  T updateData<T>(T Function(InfiniteQueryData<ReturnType, RequestData>? existingData) updateFunction) {
    if (_getInfiniteQuery == null) {
      final newData = updateFunction(null);
      _cache.setQueryData(key: _valueKey, data: newData);
      return newData;
    }

    final currentData = _getInfiniteQuery!.state.data;
    final newData = updateFunction(currentData);
    _cache.updateQuery(key: _valueKey, updateFn: (oldData) => updateFunction(oldData as InfiniteQueryData<ReturnType, RequestData>?));
    return newData;
  }

  /// Invalidate the infinite query
  void invalidate({bool refetchActive = true, bool refetchInactive = false}) {
    _getInfiniteQuery?.invalidate(refetchActive: refetchActive, refetchInactive: refetchInactive);
  }

  /// Fetch the infinite query
  Future<InfiniteQueryStatus<ReturnType, RequestData>?> Function() get fetch {
    return () async {
      if (_getInfiniteQuery == null) return Future.value(null);
      return (_getInfiniteQuery as InfiniteQuery<ReturnType, RequestData>?)?.fetch();
    };
  }

  /// Fetch the next page
  Future<InfiniteQueryStatus<ReturnType, RequestData>?> Function() get fetchNextPage {
    return () async {
      if (_getInfiniteQuery == null) return Future.value(null);
      return (_getInfiniteQuery as InfiniteQuery<ReturnType, RequestData>?)?.getNextPage();
    };
  }

  /// Refetch all pages
  Future<InfiniteQueryStatus<ReturnType, RequestData>?> Function() get refetch {
    return () async {
      if (_getInfiniteQuery == null) return Future.value(null);
      return (_getInfiniteQuery as InfiniteQuery<ReturnType, RequestData>?)?.refetch();
    };
  }
}
