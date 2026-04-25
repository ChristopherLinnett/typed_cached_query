import 'dart:async';

import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/mutation_key.dart';
import 'package:typed_cached_query/src/models/query_key.dart';
import 'package:typed_cached_query/src/models/infinite_query_key.dart';

/// Base class for creating type-safe, cacheable query requests.
///
/// Implement this class to create strongly-typed query objects that automatically handle:
/// - **Caching** with customizable cache keys
/// - **Error handling** with consistent error mapping
/// - **Response parsing** with type safety
/// - **Persistent storage** for offline access
/// - **Request serialization** for cache key generation
///
/// ## Basic Implementation
/// ```dart
/// class GetUserQuery extends QuerySerializable<User, ApiError> {
///   final int userId;
///   GetUserQuery(this.userId);
///
///   @override
///   Future<dynamic> queryFn() => api.getUser(userId);
///
///   @override
///   User responseHandler(dynamic response) => User.fromJson(response);
///
///   @override
///   QueryException errorMapper(ApiError error) =>
///     QueryException(error.message, error.statusCode);
///
///   @override
///   Map<String, dynamic> toJson() => {'userId': userId};
/// }
/// ```
///
/// ## Usage
/// ```dart
/// final query = GetUserQuery(123);
/// final result = await query.query().result;
/// ```
///
/// ## Advanced Features
/// - **Custom caching:** Override [keyGenerator] or [cache]
/// - **Persistent storage:** Set [storeQuery] to true and provide serializers
/// - **Error handling:** Implement [errorMapper] for domain-specific errors
///
/// ## Type Parameters
/// - [ReturnType]: The expected return type from successful queries
/// - [ErrorType]: Your custom error type that will be mapped to [QueryException]
abstract class QuerySerializable<ReturnType, ErrorType> {
  /// Generates a unique cache key for this query request.
  ///
  /// **Default behavior:** Uses the combination of class name and serialized JSON (`"$runtimeType-${toJson()}"`).
  /// **Override when:** You need custom caching behavior or want to group related queries under the same key.
  /// **Example:** Return a constant string to cache the same data across different request instances.
  String get keyGenerator => "$runtimeType-${toJson()}";

  /// Maps domain-specific errors to standardized [QueryException] objects.
  ///
  /// **Purpose:** Converts your custom error types into consistent error handling format.
  /// **Parameters:**
  /// - [error]: The original error of type [ErrorType] from your API/service
  /// **Returns:** A [QueryException] with appropriate error message and status code
  /// **Example:** Map HTTP status codes, validation errors, or network exceptions
  QueryException errorMapper(ErrorType error);

  /// Transforms the raw API response into your expected return type.
  ///
  /// **Purpose:** Handles JSON parsing, data transformation, and type conversion.
  /// **Parameters:**
  /// - [response]: Raw response from the API (typically JSON, but can be any type)
  /// **Returns:** Parsed and validated data of type [ReturnType]
  /// **Error handling:** If parsing fails, will throw FormatException with detailed message
  /// **Example:** Convert JSON Map to your model objects, handle nested data structures
  ReturnType responseHandler(dynamic response);

  /// The main function that executes the actual query/API call.
  ///
  /// **Purpose:** Contains your business logic for fetching data (HTTP requests, database queries, etc.)
  /// **Returns:** Raw response that will be passed to [responseHandler]
  /// **Error handling:** Should throw errors of type [ErrorType] for proper error mapping
  /// **Example:** HTTP client calls, database operations, file system access
  Future<dynamic> queryFn();

  /// Serializes this request object into a JSON-compatible map.
  ///
  /// **Purpose:** Used for cache key generation and request identification.
  /// **Requirements:** Must be consistent and unique per distinct request.
  /// **Important:** Handle ordered collections carefully - if order doesn't matter for caching, sort them.
  /// **Returns:** A map representing all request parameters that affect the query result.
  /// **Example:** `{"userId": 123, "includeDeleted": false, "sortBy": "name"}`
  Map<String, dynamic> toJson();

  /// Function to serialize query results for persistent storage.
  ///
  /// **Purpose:** Converts your [ReturnType] objects into storage-compatible format.
  /// **Default:** `null` (no storage serialization)
  /// **Override when:** You want to persist query results across app sessions.
  /// **Requirements:** Must work with [storageDeserializer] to roundtrip data.
  /// **Parameters:** Function that takes [ReturnType] and returns serializable map.
  /// **Example:** `(User user) => {"id": user.id, "name": user.name, "email": user.email}`
  Map<String, dynamic> Function(ReturnType)? get storageSerializer => null;

  /// Function to deserialize query results from persistent storage.
  ///
  /// **Purpose:** Reconstructs your [ReturnType] objects from stored data.
  /// **Default:** `null` (no storage deserialization)
  /// **Override when:** You're using [storageSerializer] and [storeQuery] is true.
  /// **Requirements:** Must be able to reconstruct objects serialized by [storageSerializer].
  /// **Parameters:** Function that takes stored map and returns [ReturnType].
  /// **Example:** `(Map<String, dynamic> map) => User.fromJson(map)`
  ReturnType Function(Map<String, dynamic>)? get storageDeserializer => null;

  /// Controls whether query results should be persisted to disk storage.
  ///
  /// **Purpose:** Enables offline access and faster app startup with cached data.
  /// **Default:** `false` (in-memory caching only)
  /// **Override to `true` when:** You want results to survive app restarts.
  /// **Requirements:**
  /// - Storage interface must be properly initialized in your app
  /// - Both [storageSerializer] and [storageDeserializer] must be provided
  /// - Will throw ArgumentError if serializers are missing
  /// **Use cases:** User profiles, settings, frequently accessed reference data
  bool get storeQuery => false;

  /// Custom cache instance for this specific query type.
  ///
  /// **Purpose:** Allows using different cache configurations per query type.
  /// **Default:** `null` (uses [CachedQuery.instance] global cache)
  /// **Override when:** You need isolated caching, custom cache policies, or testing scenarios.
  /// **Example:** Separate cache for sensitive data with different retention policies.
  CachedQuery? get cache => null;
}

/// Base class for creating type-safe mutation requests (create, update, delete operations).
///
/// Implement this class to create strongly-typed mutation objects that handle:
/// - **State mutations** with optimistic updates
/// - **Error handling** with rollback support
/// - **Response parsing** with type safety
/// - **Cache invalidation** and updates
///
/// ## Basic Implementation
/// ```dart
/// class CreateUserMutation extends MutationSerializable<CreateUserMutation, User, ApiError> {
///   final String name, email;
///   CreateUserMutation({required this.name, required this.email});
///
///   @override
///   String get keyGenerator => 'create_user';
///
///   @override
///   Future<User> mutationFn() => api.createUser(name: name, email: email);
///
///   @override
///   User responseHandler(dynamic response) => User.fromJson(response);
///
///   @override
///   OnErrorResults<CreateUserMutation, User?> errorMapper(
///     CreateUserMutation request, ApiError error, User? fallback
///   ) => OnErrorResults(
///     request: request,
///     error: MutationException(error.message, error.statusCode),
///     fallback: fallback
///   );
/// }
/// ```
///
/// ## Usage
/// ```dart
/// final mutation = CreateUserMutation(name: 'John', email: 'john@example.com');
/// final result = await mutation.mutate();
/// ```
///
/// ## Type Parameters
/// - [RequestType]: The mutation request type (usually the implementing class)
/// - [ReturnType]: The expected return type from successful mutations
/// - [ErrorType]: Your custom error type that will be mapped to [MutationException]
abstract class MutationSerializable<RequestType extends MutationSerializable<RequestType, ReturnType, ErrorType>, ReturnType, ErrorType> {
  /// Generates a unique key for this mutation type, used for caching and identifying the mutation.
  ///
  /// **Purpose:** Distinct mutations should produce distinct keys so the underlying [MutationCache]
  /// can track in-flight state, deduplicate concurrent submissions, and dispatch optimistic updates.
  /// **Returns:** A stable, unique string per mutation type. Override per request only when the
  /// mutation is parameterised by data that should partition cache state (e.g. user id).
  /// **Example:** `String get keyGenerator => 'create_user';`
  String get keyGenerator;

  /// Maps a domain-specific [ErrorType] into a typed [OnErrorResults] for the mutation pipeline.
  ///
  /// **Purpose:** Converts your custom error type into the standard [MutationException] format and
  /// optionally carries a [fallback] value used for optimistic-update rollback.
  /// **Parameters:**
  /// - [request]: The mutation request that produced the error.
  /// - [error]: The original error of type [ErrorType] from your API/service.
  /// - [fallback]: Optional fallback value (e.g. previous state) for the mutation pipeline.
  /// **Returns:** An [OnErrorResults] wrapping the mapped exception and fallback.
  /// **Example:** map HTTP status codes, validation errors, or network exceptions into [MutationException].
  OnErrorResults<RequestType, ReturnType?> errorMapper(RequestType request, ErrorType error, ReturnType? fallback);

  /// Transforms the raw mutation response into the expected [ReturnType].
  ///
  /// **Purpose:** Handles JSON parsing, data transformation, and type conversion of the value
  /// returned by [mutationFn] before it reaches `onSuccess` callbacks.
  /// **Parameters:**
  /// - [response]: Raw response from the API (typically JSON, but can be any type).
  /// **Returns:** Parsed and validated data of type [ReturnType].
  /// **Example:** `User responseHandler(dynamic response) => User.fromJson(response);`
  ReturnType responseHandler(dynamic response);

  /// The core function that performs the mutation. Returns a [Future] whose raw result is then
  /// passed through [responseHandler] to produce the typed [ReturnType].
  ///
  /// **Purpose:** Contains your business logic for performing the mutation (HTTP requests,
  /// database writes, etc.).
  /// **Returns:** Raw response that will be passed to [responseHandler].
  /// **Error handling:** Should throw errors of type [ErrorType] for proper error mapping by
  /// [errorMapper]. Any other thrown object is treated as an unhandled exception and wrapped in
  /// [MutationException].
  /// **Example:** HTTP POST/PUT/DELETE calls, database writes, file system mutations.
  Future<dynamic> mutationFn();

  /// Custom cache instance for this specific mutation type.
  ///
  /// **Purpose:** Allows isolated cache configuration per mutation type.
  /// **Default:** `null` (uses [MutationCache.instance] global cache).
  /// **Override when:** You need isolated caching, custom cache policies, or testing scenarios.
  MutationCache? get cache => null;
}

/// Base class for creating type-safe infinite/paginated query requests.
///
/// Implement this class to create strongly-typed infinite queries that handle:
/// - **Pagination** with automatic page loading
/// - **Caching** of all loaded pages
/// - **Error handling** per page
/// - **Load more** functionality
/// - **Persistent storage** for offline pagination
///
/// ## Basic Implementation
/// ```dart
/// class GetUsersInfiniteQuery extends InfiniteQuerySerializable<PagedUsers, int, ApiError> {
///   final int pageSize;
///   GetUsersInfiniteQuery({this.pageSize = 20});
///
///   @override
///   String get keyGenerator => 'users_infinite_$pageSize';
///
///   @override
///   Future<PagedUsers> queryFn(int page) =>
///     api.getUsers(page: page, limit: pageSize);
///
///   @override
///   PagedUsers responseHandler(dynamic response) => PagedUsers.fromJson(response);
///
///   @override
///   int? getNextArg(InfiniteQueryData<PagedUsers, int>? data) {
///     if (data == null) return 1;
///     final lastPage = data.pages.last;
///     return lastPage.hasMore ? data.pages.length + 1 : null;
///   }
///
///   @override
///   QueryException errorMapper(ApiError error) =>
///     QueryException(error.message, error.statusCode);
/// }
/// ```
///
/// ## Usage
/// ```dart
/// final query = GetUsersInfiniteQuery();
/// final infiniteQuery = query.infiniteQueryKey.infiniteQuery();
/// await infiniteQuery.fetchNext(); // Load more pages
/// ```
///
/// ## Type Parameters
/// - [ReturnType]: The expected return type from each page request
/// - [RequestData]: The type of data needed to request the next page (page number, cursor, etc.)
/// - [ErrorType]: Your custom error type that will be mapped to [QueryException]
abstract class InfiniteQuerySerializable<ReturnType, RequestData, ErrorType> {
  /// Generates a unique key for this infinite query type, used for caching and identifying the query.
  ///
  /// **Purpose:** Distinct infinite queries should produce distinct keys so the underlying cache
  /// can track all loaded pages and dispatch updates correctly.
  /// **Returns:** A stable, unique string per infinite query type. Override per parameterised
  /// query so different page sizes, filters, or sort orders are cached separately.
  /// **Example:** `String get keyGenerator => 'users_infinite_${pageSize}_$sortBy';`
  String get keyGenerator;

  /// Maps a domain-specific [ErrorType] into a [QueryException] for consistent error handling.
  ///
  /// **Purpose:** Converts your custom error type into the standard [QueryException] format used
  /// by the typed wrapper's `onError` plumbing.
  /// **Parameters:**
  /// - [error]: The original error of type [ErrorType] from your API/service.
  /// **Returns:** A [QueryException] with appropriate error message and status code.
  /// **Example:** map HTTP status codes, validation errors, or pagination errors.
  QueryException errorMapper(ErrorType error);

  /// Transforms the raw API response for a single page into the expected [ReturnType].
  ///
  /// **Purpose:** Handles JSON parsing, data transformation, and type conversion of each page.
  /// **Parameters:**
  /// - [response]: Raw response from the API (typically JSON, but can be any type).
  /// **Returns:** Parsed and validated data of type [ReturnType] representing one page.
  /// **Example:** `PagedResponse responseHandler(dynamic response) => PagedResponse.fromJson(response);`
  ReturnType responseHandler(dynamic response);

  /// The core function that fetches a single page/chunk. Returns a [Future] whose raw result is
  /// then passed through [responseHandler] to produce the typed [ReturnType].
  ///
  /// **Purpose:** Contains your business logic for fetching a specific page given the page-pointer
  /// produced by [getNextArg].
  /// **Parameters:**
  /// - [requestData]: The page-pointer (typically page number, offset, or cursor) returned by
  ///   [getNextArg] for the page about to be fetched.
  /// **Returns:** Raw response for one page, passed to [responseHandler].
  /// **Error handling:** Throw errors of type [ErrorType] for proper mapping by [errorMapper].
  Future<dynamic> queryFn(RequestData requestData);

  /// Determines the argument for the next page based on the current infinite query data.
  ///
  /// **Return** the next [RequestData] argument to fetch a further page, or `null` when there
  /// are no more pages to load.
  ///
  /// **Error contract:** if this method throws, the failure is propagated to the underlying
  /// `InfiniteQuery` and surfaces as an error state (rather than silently terminating pagination).
  /// Errors of type [ErrorType] flow through [errorMapper]; any other thrown object is wrapped in
  /// a generic [QueryException] before being delivered to the user-supplied `onError` callback.
  RequestData? getNextArg(InfiniteQueryData<ReturnType, RequestData>? data);

  /// Function to serialize the full [InfiniteQueryData] (all loaded pages + their args) for persistent storage.
  ///
  /// **Purpose:** Converts the complete pagination state into a storage-compatible map so the
  /// already-loaded pages can survive app restarts.
  /// **Default:** `null` (no storage serialization).
  /// **Override when:** [storeQuery] is true and you want pagination state to persist.
  /// **Requirements:** Must round-trip with [storageDeserializer].
  Map<String, dynamic> Function(InfiniteQueryData<ReturnType, RequestData>)? get storageSerializer => null;

  /// Function to deserialize stored pagination state into [InfiniteQueryData].
  ///
  /// **Purpose:** Reconstructs all previously loaded pages and their request args from disk.
  /// **Default:** `null` (no storage deserialization).
  /// **Override when:** Using [storageSerializer] with [storeQuery] set to true.
  /// **Requirements:** Must reconstruct the data produced by [storageSerializer].
  InfiniteQueryData<ReturnType, RequestData> Function(Map<String, dynamic>)? get storageDeserializer => null;

  /// Controls whether infinite query pages should be persisted to disk storage.
  ///
  /// **Purpose:** Enables offline access and faster app startup with previously loaded pages.
  /// **Default:** `false` (in-memory caching only).
  /// **Override to `true` when:** You want the infinite query state to survive app restarts.
  /// **Requirements:** Both [storageSerializer] and [storageDeserializer] must be provided, and the
  /// storage interface must be initialised via `TypedCachedQuery.configureFlutter`.
  bool get storeQuery => false;

  /// Custom cache instance for this specific infinite query type.
  ///
  /// **Purpose:** Allows isolated cache configuration per query type.
  /// **Default:** `null` (uses [CachedQuery.instance] global cache).
  /// **Override when:** You need isolated caching, custom cache policies, or testing scenarios.
  CachedQuery? get cache => null;
}

extension QuerySerializableExtension<T extends QuerySerializable<ReturnType, ErrorType>, ReturnType, ErrorType> on T {
  /// Returns a [QueryKey] for state inspection (`exists`, `isPending`, `error`, `invalidate`,
  /// `updateData`, `fetch`, etc.). Most rendering paths should use [query] instead.
  QueryKey<T, ReturnType, ErrorType> get queryKey => QueryKey(this);

  /// Convenience entry point: build a configured `Query` directly from the serializable.
  ///
  /// **Purpose:** Replaces the previous `request.queryKey.query(...)` chain — `*Key` is a
  /// wrapper-internal abstraction, not part of the rendering path. Per-builder configuration
  /// (`onSuccess`, `onError`, `config`, `cache`) is preserved so different builders can resolve
  /// the same serializable with different behaviour.
  /// **Example:**
  /// ```dart
  /// TypedQueryBuilder<User>(
  ///   query: getUserQuery.query(onSuccess: (u) => analytics.userLoaded(u)),
  ///   builder: (context, state) => ...,
  /// )
  /// ```
  /// **Returns:** A configured [Query] backed by the same `*Key` implementation.
  Query<ReturnType> query({
    void Function(QueryException)? onError,
    void Function(ReturnType)? onSuccess,
    QueryConfig<ReturnType>? config,
    CachedQuery? cache,
  }) => queryKey.query(onError: onError, onSuccess: onSuccess, config: config, cache: cache);
}

extension MutationSerializableExtension<T extends MutationSerializable<T, ReturnType, ErrorType>, ReturnType, ErrorType> on T {
  /// Returns a [MutationKey] for state inspection (`exists`, `isPending`, `error`, etc.).
  /// Most rendering paths should use [definition] to build a `Mutation` for builders, or [mutate]
  /// to trigger a single mutation directly.
  MutationKey<T, ReturnType, ErrorType> get mutationKey => MutationKey(this);

  /// Convenience entry point: build a configured `Mutation` directly from the serializable for
  /// use with `TypedMutationBuilder` / `TypedMutationListener`.
  ///
  /// **Purpose:** Replaces the previous `request.mutationKey.definition(...)` chain — `*Key` is a
  /// wrapper-internal abstraction, not part of the rendering path. Per-builder configuration
  /// (`onSuccess`, `onError`, `cache`, retry/timeout, optimistic updates) is preserved.
  /// **Example:**
  /// ```dart
  /// TypedMutationBuilder<User, UpdateUserRequest>(
  ///   mutation: updateUserMutation.definition(onSuccess: (user, _) => toast(user)),
  ///   builder: (context, state, mutate) => ...,
  /// )
  /// ```
  /// **Returns:** A configured [Mutation] backed by the same `*Key` implementation.
  Mutation<ReturnType, T> definition({
    void Function(T, MutationException, ReturnType?)? onError,
    void Function(ReturnType, T)? onSuccess,
    MutationCache? cache,
    FutureOr<ReturnType> Function(T)? onStartMutation,
    List<QueryKey<dynamic, dynamic, dynamic>>? invalidateQueries,
    List<QueryKey<dynamic, dynamic, dynamic>>? refetchQueries,
    int? retryAttempts,
    bool Function(ErrorType)? shouldRetry,
    int? timeoutSeconds,
    void Function(T)? onTimeout,
    Duration Function(int attempt)? backoff,
  }) => mutationKey.definition(
        onError: onError,
        onSuccess: onSuccess,
        cache: cache,
        onStartMutation: onStartMutation,
        invalidateQueries: invalidateQueries,
        refetchQueries: refetchQueries,
        retryAttempts: retryAttempts,
        shouldRetry: shouldRetry,
        timeoutSeconds: timeoutSeconds,
        onTimeout: onTimeout,
        backoff: backoff,
      );

  /// Convenience entry point: trigger this mutation directly from the serializable.
  ///
  /// **Purpose:** Replaces the previous `mutation.mutationKey.mutate(...)` chain with a single
  /// verb on the serializable. The full named-parameter surface of [MutationKey] is preserved.
  /// **Example:**
  /// ```dart
  /// final result = await createUserMutation.mutate(
  ///   onSuccess: (user, _) => print(user),
  /// );
  /// ```
  /// **Returns:** A [Future] resolving to the final [MutationState], identical to the
  /// `mutationKey.definition(...).mutate(request)` path used internally.
  Future<MutationState<ReturnType?>> mutate({
    void Function(T, MutationException, ReturnType?)? onError,
    void Function(ReturnType, T)? onSuccess,
    MutationCache? cache,
    FutureOr<ReturnType> Function(T)? onStartMutation,
    List<QueryKey<dynamic, dynamic, dynamic>>? invalidateQueries,
    List<QueryKey<dynamic, dynamic, dynamic>>? refetchQueries,
    int? retryAttempts,
    bool Function(ErrorType)? shouldRetry,
    int? timeoutSeconds,
    void Function(T)? onTimeout,
    Duration Function(int attempt)? backoff,
  }) => mutationKey
      .definition(
        onError: onError,
        onSuccess: onSuccess,
        cache: cache,
        onStartMutation: onStartMutation,
        invalidateQueries: invalidateQueries,
        refetchQueries: refetchQueries,
        retryAttempts: retryAttempts,
        shouldRetry: shouldRetry,
        timeoutSeconds: timeoutSeconds,
        onTimeout: onTimeout,
        backoff: backoff,
      )
      .mutate(this);
}

extension InfiniteQuerySerializableExtension<
  T extends InfiniteQuerySerializable<ReturnType, RequestData, ErrorType>,
  ReturnType,
  RequestData,
  ErrorType
>
    on T {
  /// Returns an [InfiniteQueryKey] for state inspection (`exists`, `isPending`, `hasReachedMax`,
  /// `allPages`, `pageArgs`, `fetch`, `fetchNextPage`, `refetch`, `invalidate`, `updateData`,
  /// `error`). Most rendering paths should use [infiniteQuery] instead.
  InfiniteQueryKey<T, ReturnType, RequestData, ErrorType> get infiniteQueryKey => InfiniteQueryKey(this);

  /// Convenience entry point: build a configured `InfiniteQuery` directly from the serializable.
  ///
  /// **Purpose:** Replaces the previous `request.infiniteQueryKey.query(...)` chain — `*Key` is a
  /// wrapper-internal abstraction, not part of the rendering path. Per-builder configuration
  /// (`onSuccess`, `onError`, `config`, `cache`, `prefetchPages`, `initialData`) is preserved.
  /// **Example:**
  /// ```dart
  /// TypedInfiniteQueryBuilder<Page, Args>(
  ///   query: feed.infiniteQuery(prefetchPages: 2),
  ///   builder: (context, state) => ...,
  /// )
  /// ```
  /// **Returns:** A configured [InfiniteQuery] backed by the same `*Key` implementation.
  InfiniteQuery<ReturnType, RequestData> infiniteQuery({
    void Function(QueryException)? onError,
    void Function(InfiniteQueryData<ReturnType, RequestData>)? onSuccess,
    QueryConfig<InfiniteQueryData<ReturnType, RequestData>>? config,
    CachedQuery? cache,
    int? prefetchPages,
    InfiniteQueryData<ReturnType, RequestData>? initialData,
  }) => infiniteQueryKey.query(
        onError: onError,
        onSuccess: onSuccess,
        config: config,
        cache: cache,
        prefetchPages: prefetchPages,
        initialData: initialData,
      );
}

class OnErrorResults<RequestType, ReturnType> {
  final RequestType request;
  final MutationException error;
  final ReturnType? fallback;
  const OnErrorResults({required this.request, required this.error, this.fallback});
}
