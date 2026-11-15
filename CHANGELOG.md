# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Requires `cached_query_flutter: ^3.4.1` (`cached_query` 3.7.1), up from `^3.3.1`. The new floor carries two upstream cache fixes: a query stays invalidated when its refetch fails, and fetching an inactive query no longer leaks its delete timer.
- **Behaviour change:** a `QueryConfig` passed to `request.query(config: ...)` or `request.infiniteQuery(config: ...)` now overrides only the fields it sets. Before, passing any config replaced every unset field (`staleDuration`, `cacheDuration`, `shouldRethrow`, `ignoreCacheDuration`, `refetchOnResume`, `refetchOnConnection`, `shouldFetch`) with the library default, discarding the `GlobalQueryConfig`: an app that turned `refetchOnResume` off globally had it switched back on for each query that passed a config. Queries that pass a config and relied on the library defaults (4 second stale window, refetch on resume and on reconnect) must now set those fields themselves.

### Added
- `RetryConfig` is exported, and a `retryConfig` on a per-query `QueryConfig` now reaches the query; it was dropped before, leaving only a global one in effect.
- `InfiniteQuerySerializable.getPrevArg` (defaults to no previous page, so existing subclasses are unaffected), with `fetchPreviousPage`, `hasPreviousPage` and `hasNextPage` on `InfiniteQueryKey`. `hasReachedMax` is unchanged.
- `queryCache` on `MutationKey.definition`, `MutationSerializableExtension.definition` and `.mutate`: the cache `invalidateQueries` and `refetchQueries` act on. Without it they act on `CachedQuery.instance`, as before.

### Fixed
- `TypedQueryBuilder`, `TypedInfiniteQueryBuilder`, `TypedQueryListener`, `TypedMutationBuilder` and `TypedMutationListener` no longer cancel and re-subscribe on every parent rebuild. `didUpdateWidget` compared the streams, and `Subject.stream` returns a new wrapper object per call, so the comparison was never equal; re-listening to a `Query` runs its listen-to-fetch path, which refetches whenever the data is stale, so any surface with a rebuilding ancestor refetched every query under it once per stale window. The subscription now moves only when the query or mutation object itself changes.

### Added
- `QuerySerializableExtension.query({...})` — convenience method on the serializable, replaces the `request.queryKey.query(...)` chain. Same parameter surface as `QueryKey.query()`.
- `InfiniteQuerySerializableExtension.infiniteQuery({...})` — convenience method on the serializable, replaces the `request.infiniteQueryKey.query(...)` chain. Same parameter surface as `InfiniteQueryKey.query()`.
- `MutationSerializableExtension.definition({...})` — convenience method on the serializable, replaces the `request.mutationKey.definition(...)` chain when constructing a long-lived `Mutation` for `TypedMutationBuilder` / `TypedMutationListener`.
- `MutationSerializableExtension.mutate({...})` — direct mutate verb on the serializable. Replaces the previous `request.mutationKey.mutate(...)` chain.

### Changed (breaking)
- `MutationKey.mutate(...)` is removed. Migrate to `request.mutate(...)`:
  ```dart
  // before
  await mutation.mutationKey.mutate(onSuccess: (...) => ...);
  // after
  await mutation.mutate(onSuccess: (...) => ...);
  ```
- `request.queryKey.query(...)` / `request.infiniteQueryKey.query(...)` / `request.mutationKey.definition(...)` chains in builder construction sites should migrate to the new convenience methods. The `*Key.query(...)` / `*Key.definition(...)` methods themselves remain available for advanced cases, but the `*Key` getters are intended for state-inspection (`exists`, `isPending`, `error`, `invalidate`, `updateData`) — not the rendering path.
  ```dart
  // before
  TypedQueryBuilder(query: getUserQuery.queryKey.query(), builder: ...)
  TypedInfiniteQueryBuilder(query: feed.infiniteQueryKey.query(), builder: ...)
  TypedMutationBuilder(mutation: updateUser.mutationKey.definition(...), builder: ...)
  // after
  TypedQueryBuilder(query: getUserQuery.query(), builder: ...)
  TypedInfiniteQueryBuilder(query: feed.infiniteQuery(), builder: ...)
  TypedMutationBuilder(mutation: updateUser.definition(...), builder: ...)
  ```
- `MutationSerializable.mutationFn()` and `InfiniteQuerySerializable.queryFn(arg)` now return `Future<dynamic>` (matching `QuerySerializable.queryFn()`) and their result is passed through `responseHandler` before reaching the caller. Existing implementations whose return type was `Future<ReturnType>` continue to compile (Future<X> assigns to Future<dynamic>) and continue to work as long as their `responseHandler` accepts a `ReturnType` value (which all in-tree fixtures do).

### Fixed
- `QueryKey.query()` now names the actual `ReturnType` in the `FormatException` message instead of the literal "Type".

## [0.0.1] - 2025-12-16

Initial release of `typed_cached_query`, a type-safe wrapper around `cached_query_flutter`.

### Added
- `QuerySerializable<ReturnType, ErrorType>` — base class for type-safe queries with caching, response parsing, error mapping, optional persistent storage, and customisable cache keys.
- `MutationSerializable<RequestType, ReturnType, ErrorType>` — base class for type-safe mutations with retry, timeout, and error-mapping support.
- `InfiniteQuerySerializable<ReturnType, RequestData, ErrorType>` — base class for paginated queries with cursor/page-arg support and per-page caching.
- `QueryKey`, `MutationKey`, `InfiniteQueryKey` — handles that build queries/mutations from a serializable and expose state inspection (`exists`, `isPending`, `isError`, `error`).
- `TypedQueryBuilder`, `TypedMutationBuilder`, `TypedInfiniteQueryBuilder` — Flutter widget builders that rebuild on stream events.
- `TypedQueryListener`, `TypedMutationListener` — Flutter widget listeners with lifecycle callbacks (`onChange`, `onError`, `onSuccess`, `onLoading`, `onRefetching`).
- `QueryException`, `MutationException` — typed exception classes with `==`/`hashCode` and status-code semantics.
- `TypedCachedQuery.configureFlutter(...)` — initialisation helper that wraps `CachedQuery.instance.configFlutter`.
- `TypedCachedQuery.createNewInstance()` / `createNewMutationCache()` — isolated cache instances for testing.

[Unreleased]: https://github.com/ChristopherLinnett/typed_cached_query/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/ChristopherLinnett/typed_cached_query/releases/tag/v0.0.1
