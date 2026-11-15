// Covers the surface of cached_query 3.4 → 3.7 that the wrapper has to carry rather than drop:
// global-config inheritance, query retry, previous-page fetching and the mutation's query cache.
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/typed_cached_query.dart';

class _ApiError {
  final String message;
  const _ApiError(this.message);
}

/// A query whose `queryFn` fails with [_ApiError] for its first [failures] calls, then returns its id.
class _NumberQuery extends QuerySerializable<int, _ApiError> {
  final int id;
  final int failures;
  final CachedQuery _cache;
  int calls = 0;

  _NumberQuery(this.id, this._cache, {this.failures = 0});

  @override
  CachedQuery get cache => _cache;

  @override
  Map<String, dynamic> toJson() => {'id': id};

  @override
  QueryException errorMapper(_ApiError error) => QueryException(error.message, 503);

  @override
  int responseHandler(dynamic response) => response as int;

  @override
  Future<dynamic> queryFn() async {
    calls++;
    if (calls <= failures) throw const _ApiError('unavailable');
    return id;
  }
}

/// Pages are their own page number; the window opens at [start] and spans [first]..[last].
class _WindowQuery extends InfiniteQuerySerializable<int, int, _ApiError> {
  static const first = 1;
  static const last = 5;
  final int start;
  final CachedQuery _cache;

  _WindowQuery(this._cache, {this.start = 3});

  @override
  String get keyGenerator => 'window-$start';

  @override
  CachedQuery get cache => _cache;

  @override
  QueryException errorMapper(_ApiError error) => QueryException(error.message, 503);

  @override
  int responseHandler(dynamic response) => response as int;

  @override
  Future<dynamic> queryFn(int page) async => page;

  @override
  int? getNextArg(InfiniteQueryData<int, int>? data) {
    if (data == null || data.pages.isEmpty) return start;
    return data.pages.last < last ? data.pages.last + 1 : null;
  }

  @override
  int? getPrevArg(InfiniteQueryData<int, int>? data) {
    if (data == null || data.pages.isEmpty) return null;
    return data.pages.first > first ? data.pages.first - 1 : null;
  }
}

/// The same window with no `getPrevArg` override — the shape every existing subclass has.
class _ForwardOnlyQuery extends InfiniteQuerySerializable<int, int, _ApiError> {
  final CachedQuery _cache;
  _ForwardOnlyQuery(this._cache);

  @override
  String get keyGenerator => 'forward-only';

  @override
  CachedQuery get cache => _cache;

  @override
  QueryException errorMapper(_ApiError error) => QueryException(error.message, 503);

  @override
  int responseHandler(dynamic response) => response as int;

  @override
  Future<dynamic> queryFn(int page) async => page;

  @override
  int? getNextArg(InfiniteQueryData<int, int>? data) => (data?.pages.length ?? 0) < 2 ? (data?.pages.length ?? 0) + 1 : null;
}

class _Rename extends MutationSerializable<_Rename, String, _ApiError> {
  final String name;
  final MutationCache _cache;
  final bool fails;
  _Rename(this.name, this._cache, {this.fails = false});

  @override
  String get keyGenerator => 'rename-$name';

  @override
  MutationCache get cache => _cache;

  @override
  OnErrorResults<_Rename, String?> errorMapper(_Rename request, _ApiError error, String? fallback) =>
      OnErrorResults(request: request, error: MutationException(error.message, 503), fallback: fallback);

  @override
  String responseHandler(dynamic response) => response as String;

  @override
  Future<dynamic> mutationFn() async => fails ? throw const _ApiError('rejected') : name;
}

const _global = GlobalQueryConfig(
  refetchOnResume: false,
  refetchOnConnection: false,
  staleDuration: Duration(minutes: 9),
  cacheDuration: Duration(minutes: 7),
  shouldRethrow: true,
  ignoreCacheDuration: true,
  retryConfig: RetryConfig(maxRetries: 3),
);

Duration _noDelay(int attempt) => Duration.zero;

void _expectInheritsGlobal(QueryConfig<dynamic> config) {
  expect(config.refetchOnResume, isFalse);
  expect(config.refetchOnConnection, isFalse);
  expect(config.staleDuration, const Duration(minutes: 9));
  expect(config.cacheDuration, const Duration(minutes: 7));
  expect(config.shouldRethrow, isTrue);
  expect(config.ignoreCacheDuration, isTrue);
}

void main() {
  late CachedQuery cache;

  setUp(() => cache = CachedQuery.asNewInstance()..config(config: _global));

  group('global config inheritance', () {
    test('a query built with no config inherits the global config', () {
      final config = _NumberQuery(1, cache).query().config;

      _expectInheritsGlobal(config);
      expect(config.retryConfig?.maxRetries, 3);
    });

    test('a query built with a config inherits the global config for every field the config leaves unset', () {
      final config = _NumberQuery(2, cache).query(config: QueryConfig(pollInactive: true)).config;

      _expectInheritsGlobal(config);
      expect(config.pollInactive, isTrue);
      expect(config.retryConfig?.maxRetries, 3);
    });

    test('a field the config sets wins over the global config', () {
      final config = _NumberQuery(3, cache).query(config: QueryConfig(staleDuration: Duration.zero, refetchOnResume: true)).config;

      expect(config.staleDuration, Duration.zero);
      expect(config.refetchOnResume, isTrue);
      expect(config.refetchOnConnection, isFalse);
      expect(config.cacheDuration, const Duration(minutes: 7));
    });

    test('a global shouldFetch is inherited when the config sets none', () {
      final gated = CachedQuery.asNewInstance()..config(config: GlobalQueryConfig(shouldFetch: (_, _, _) => false));

      final config = _NumberQuery(4, gated).query(config: QueryConfig(pollInactive: true)).config;

      expect(config.shouldFetch('key', null, DateTime(2026)), isFalse);
    });

    test('an infinite query built with a config inherits the global config for every field the config leaves unset', () {
      final config = _WindowQuery(cache).infiniteQuery(config: QueryConfig(pollInactive: true)).config;

      _expectInheritsGlobal(config);
      expect(config.pollInactive, isTrue);
      expect(config.retryConfig?.maxRetries, 3);
    });

    test('a cache passed at the call site supplies the global config, not the request cache', () {
      final other = CachedQuery.asNewInstance()..config(config: const GlobalQueryConfig(staleDuration: Duration(hours: 1)));

      final config = _NumberQuery(5, cache).query(cache: other, config: QueryConfig(pollInactive: true)).config;

      expect(config.staleDuration, const Duration(hours: 1));
    });
  });

  group('query retry', () {
    test('a per-query retryConfig reaches the query, over the global one', () {
      final config = _NumberQuery(10, cache).query(config: QueryConfig(retryConfig: const RetryConfig(maxRetries: 5))).config;

      expect(config.retryConfig?.maxRetries, 5);
    });

    test('a per-query retryConfig reaches the infinite query, over the global one', () {
      final config = _WindowQuery(cache).infiniteQuery(config: QueryConfig(retryConfig: const RetryConfig(maxRetries: 5))).config;

      expect(config.retryConfig?.maxRetries, 5);
    });

    test('a failing queryFn is retried up to maxRetries and then succeeds', () async {
      final request = _NumberQuery(11, cache, failures: 2);

      final state = await request
          .query(
            config: QueryConfig(shouldRethrow: false, retryConfig: const RetryConfig(maxRetries: 2, delay: _noDelay)),
          )
          .fetch();

      expect(request.calls, 3);
      expect(state.data, 11);
      expect(state.isError, isFalse);
    });

    test('when retries are exhausted the error still maps through errorMapper', () async {
      final request = _NumberQuery(12, cache, failures: 10);
      QueryException? reported;

      await request
          .query(
            onError: (error) => reported = error,
            config: QueryConfig(shouldRethrow: false, retryConfig: const RetryConfig(maxRetries: 1, delay: _noDelay)),
          )
          .fetch();

      expect(request.calls, 2);
      expect(reported?.message, 'unavailable');
      expect(reported?.statusCode, 503);
      expect(request.queryKey.error?.statusCode, 503);
    });

    test('whenError sees the request ErrorType and can refuse the retry', () async {
      final request = _NumberQuery(13, cache, failures: 10);
      final seen = <Object>[];

      await request
          .query(
            config: QueryConfig(
              shouldRethrow: false,
              retryConfig: RetryConfig(
                maxRetries: 4,
                delay: _noDelay,
                whenError: (error, attempt) {
                  seen.add(error);
                  return false;
                },
              ),
            ),
          )
          .fetch();

      expect(request.calls, 1);
      expect(seen.single, isA<_ApiError>());
    });
  });

  group('previous page', () {
    test('fetchPreviousPage prepends the page getPrevArg names', () async {
      final request = _WindowQuery(cache);
      final key = request.infiniteQueryKey;
      await request.infiniteQuery().fetch();

      await key.fetchPreviousPage();

      expect(key.allPages, [2, 3]);
      expect(key.pageArgs, [2, 3]);
    });

    test('hasPreviousPage and hasNextPage follow the two ends of the window', () async {
      final request = _WindowQuery(cache, start: 2);
      final key = request.infiniteQueryKey;
      expect(key.hasPreviousPage, isFalse, reason: 'no query exists yet');
      expect(key.hasNextPage, isFalse, reason: 'no query exists yet');
      await request.infiniteQuery().fetch();

      expect(key.hasPreviousPage, isTrue);
      expect(key.hasNextPage, isTrue);

      await key.fetchPreviousPage();

      expect(key.allPages, [1, 2]);
      expect(key.hasPreviousPage, isFalse);
      expect(key.hasNextPage, isTrue);
      expect(key.hasReachedMax, isFalse);
    });

    test('fetchPreviousPage at the start of the window changes nothing', () async {
      final request = _WindowQuery(cache, start: _WindowQuery.first);
      final key = request.infiniteQueryKey;
      await request.infiniteQuery().fetch();

      await key.fetchPreviousPage();

      expect(key.allPages, [1]);
    });

    test('a serializable that declares no getPrevArg has no previous page and fetching one changes nothing', () async {
      final request = _ForwardOnlyQuery(cache);
      final key = request.infiniteQueryKey;
      await request.infiniteQuery().fetch();

      expect(key.hasPreviousPage, isFalse);
      await key.fetchPreviousPage();

      expect(key.allPages, [1]);
    });

    test('fetchPreviousPage on a query that does not exist returns null', () async {
      expect(await _WindowQuery(cache).infiniteQueryKey.fetchPreviousPage(), isNull);
    });
  });

  group('mutation query cache', () {
    late MutationCache mutations;

    setUp(() => mutations = MutationCache.asNewInstance());

    test('invalidateQueries invalidates the query in the queryCache passed to mutate', () async {
      final request = _NumberQuery(20, cache);
      await request.query(config: QueryConfig(shouldRethrow: false)).fetch();
      expect(request.calls, 1);

      await _Rename('a', mutations).mutate(queryCache: cache, invalidateQueries: [request.queryKey]);
      await request.query(config: QueryConfig(shouldRethrow: false)).fetch();

      expect(request.calls, 2, reason: 'the 9 minute stale window is still open, so only an invalidation refetches');
    });

    test('refetchQueries refetches the query in the queryCache passed to definition', () async {
      final request = _NumberQuery(21, cache);
      await request.query(config: QueryConfig(shouldRethrow: false)).fetch();

      final rename = _Rename('b', mutations);
      await rename.definition(queryCache: cache, refetchQueries: [request.queryKey]).mutate(rename);
      await pumpEventQueue();

      expect(request.calls, 2);
    });

    test('without a queryCache the mutation still targets the default instance', () async {
      final request = _NumberQuery(22, cache);
      await request.query(config: QueryConfig(shouldRethrow: false)).fetch();

      await _Rename('c', mutations).mutate(invalidateQueries: [request.queryKey]);
      await request.query(config: QueryConfig(shouldRethrow: false)).fetch();

      expect(request.calls, 1, reason: 'the query lives in another cache, which this mutation was never told about');
    });

    test('the error getter reads the mapped error from the mutation state', () async {
      final rename = _Rename('d', mutations, fails: true);

      await rename.mutate();

      expect(rename.mutationKey.error?.message, 'rejected');
      expect(rename.mutationKey.error?.statusCode, 503);
    });
  });
}
