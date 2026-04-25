# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
