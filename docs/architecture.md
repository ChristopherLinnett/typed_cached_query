# Architecture: abstraction posture

## Decision

`typed_cached_query` is a **typed shim** over [`cached_query_flutter`](https://pub.dev/packages/cached_query_flutter) — not a self-contained façade.

The library adds compile-time type safety on the **input** side of every query/mutation/infinite query (request payload, error type, return type, page-pointer type) but deliberately **returns the underlying `cached_query_flutter` types** (`Query<T>`, `Mutation<T, R>`, `InfiniteQuery<T, A>`, `QueryStatus<T>`, `MutationState<T>`, `InfiniteQueryStatus<T, A>`) and re-exports their public surface from the package barrel.

Consumers therefore still need to learn the relevant parts of `cached_query_flutter` (state shapes, configuration knobs, lifecycle hooks). The wrapper is **not a substitute** for understanding the upstream package.

## Why this posture

- **Lower cost.** Owning the surface would require introducing wrapper-controlled state types and a parallel API for every cached_query primitive that consumers need to inspect. That is a substantial multi-step refactor disproportionate to the value.
- **Avoid leaky-by-accident abstractions.** A partial façade is worse than honesty: callers need to know when to look at the wrapper vs. the underlying type, and that line moves every time the underlying API changes.
- **Re-exports stay narrow and intentional.** The barrel re-exports the types consumers actually need to handle — see [`lib/typed_cached_query.dart`](../lib/typed_cached_query.dart). It does not blanket-export everything from `cached_query_flutter`.

## What this means in practice

- **Inputs are typed.** `QuerySerializable<ReturnType, ErrorType>`, `MutationSerializable<RequestType, ReturnType, ErrorType>`, and `InfiniteQuerySerializable<ReturnType, RequestData, ErrorType>` enforce strong typing for the user-supplied callbacks (`queryFn`, `responseHandler`, `errorMapper`, `getNextArg`, `mutationFn`).
- **Cache key generation is unified.** All three serializables expose `String get keyGenerator`.
- **Builders and listeners adapt the underlying streams.** `TypedQueryBuilder`, `TypedMutationBuilder`, `TypedInfiniteQueryBuilder`, `TypedQueryListener`, `TypedMutationListener` are thin wrappers over the upstream `Query.stream` / `Mutation.stream` / `InfiniteQuery.stream`.
- **Error handling is uniform.** `QueryException` and `MutationException` are owned by this library; the `errorMapper` contract translates `ErrorType → QueryException/MutationException` consistently.
- **Outputs are upstream types.** `queryKey.query()` returns `Query<T>`; `mutationKey.definition()` returns `Mutation<T, R>`; `infiniteQueryKey.query()` returns `InfiniteQuery<T, A>`. Consumers introspect `state` / `stream` / `fetch()` / `getNextPage()` directly on those.

## When to revisit

Re-open the question if any of these become true:

- The wrapper grows enough non-trivial logic above the upstream API that "shim" stops describing it.
- A breaking change in `cached_query_flutter` would be cleaner to absorb behind a stable wrapper interface.
- A second backend (not `cached_query_flutter`) becomes a real possibility — at that point owning the surface earns its keep.

Until one of those is true, keep this library as a typed shim and document any drift away from upstream behaviour explicitly.
