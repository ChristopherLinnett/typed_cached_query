# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
