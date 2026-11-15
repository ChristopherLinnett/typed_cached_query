import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/query_config_builder.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

class InfiniteQueryKey<RequestType extends InfiniteQuerySerializable<ReturnType, RequestData, ErrorType>, ReturnType, RequestData, ErrorType> {
  final RequestType request;
  InfiniteQueryKey(this.request);

  String get _valueKey => request.keyGenerator;
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
    final queryConfig = buildQueryConfig<InfiniteQueryData<ReturnType, RequestData>>(
      config: config,
      global: queryCache.defaultConfig,
      storeQuery: request.storeQuery,
      storageSerializer: request.storageSerializer,
      storageDeserializer: request.storageDeserializer,
      owner: 'InfiniteQueryKey<$RequestType, $ReturnType, $RequestData, $ErrorType>',
    );

    return InfiniteQuery<ReturnType, RequestData>(
      key: _valueKey,
      queryFn: (RequestData arg) async {
        dynamic raw;
        try {
          raw = await request.queryFn(arg);
        } catch (e) {
          if (e is ErrorType) rethrow;
          throw QueryException(
            'An unhandled exception has taken place, please update your definitions to include this error, error: ${e.toString()}',
            500,
          );
        }
        try {
          return request.responseHandler(raw);
        } catch (e) {
          throw QueryException('parsing the response of type ${raw.runtimeType} to $ReturnType failed: ${e.toString()}', 400);
        }
      },
      getNextArg: _guardedPageArg(request.getNextArg, 'getNextArg'),
      getPrevArg: _guardedPageArg(request.getPrevArg, 'getPrevArg'),
      onError: (error) {
        if (error is QueryException) {
          onError?.call(error);
          return;
        }
        if (error is ErrorType) {
          onError?.call(request.errorMapper(error));
          return;
        }
        onError?.call(QueryException('An unhandled exception occurred: ${error.toString()}', 500));
      },
      onSuccess: onSuccess,
      config: queryConfig,
      cache: queryCache,
      prefetchPages: prefetchPages,
      initialData: initialData,
    );
  }

  /// Wraps a page-argument callback so a failure inside it surfaces the same way a failure inside `queryFn` does:
  /// the request's own [ErrorType] passes through, anything else becomes a 500 [QueryException] naming [name].
  GetNextArg<ReturnType, RequestData> _guardedPageArg(GetNextArg<ReturnType, RequestData> pageArg, String name) {
    return (InfiniteQueryData<ReturnType, RequestData>? data) {
      try {
        return pageArg(data);
      } catch (e) {
        if (e is ErrorType) rethrow;
        throw QueryException('An unhandled exception occurred in $name: ${e.toString()}', 500);
      }
    };
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

  /// The cached entry as the infinite query this key built, or `null` when there is none.
  InfiniteQuery<ReturnType, RequestData>? get _liveInfiniteQuery {
    final query = _getInfiniteQuery;
    return query is InfiniteQuery<ReturnType, RequestData> ? query : null;
  }

  /// Whether [getNextArg][InfiniteQuerySerializable.getNextArg] names a page after the last one held.
  /// `false` while the query does not exist.
  bool get hasNextPage => _liveInfiniteQuery?.hasNextPage() ?? false;

  /// Whether [getPrevArg][InfiniteQuerySerializable.getPrevArg] names a page before the first one held.
  /// `false` while the query does not exist, and always `false` for a request that declares no `getPrevArg`.
  bool get hasPreviousPage => _liveInfiniteQuery?.hasPreviousPage() ?? false;

  /// Whether the query exists and has no next page. With previous-page fetching this says nothing about the
  /// other end of the list — read [hasNextPage] and [hasPreviousPage] when both ends matter.
  bool get hasReachedMax {
    if (_getInfiniteQuery == null) return false;
    final live = _liveInfiniteQuery;
    if (live != null) return !live.hasNextPage();
    final state = _getInfiniteQuery!.state;
    return state is InfiniteQuerySuccess<ReturnType, RequestData> && !state.hasNextPage;
  }

  QueryException? get error {
    if (_getInfiniteQuery == null) return null;
    if (!_getInfiniteQuery!.state.isError) return null;
    final stateError = _getInfiniteQuery!.state.error;
    if (stateError == null) return null;
    if (stateError is QueryException) return stateError;
    if (stateError is ErrorType) return request.errorMapper(stateError);
    return QueryException('Unhandled error: $stateError', 500);
  }

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
      final initial = updateFunction(null);
      _cache.setQueryData(key: _valueKey, data: initial);
      return initial;
    }
    final next = updateFunction(_getInfiniteQuery!.state.data);
    _cache.updateQuery(key: _valueKey, updateFn: (_) => next);
    return next;
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

  /// Fetch the page before the first one held, as named by the request's `getPrevArg`, and prepend it.
  /// Leaves the data as it is when there is no previous page.
  Future<InfiniteQueryStatus<ReturnType, RequestData>?> Function() get fetchPreviousPage {
    return () async => _liveInfiniteQuery?.getPreviousPage();
  }

  /// Refetch all pages
  Future<InfiniteQueryStatus<ReturnType, RequestData>?> Function() get refetch {
    return () async {
      if (_getInfiniteQuery == null) return Future.value(null);
      return (_getInfiniteQuery as InfiniteQuery<ReturnType, RequestData>?)?.refetch();
    };
  }
}
