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

  Query<ReturnType> Function({
    void Function(QueryException)? onError,
    void Function(ReturnType)? onSuccess,
    QueryConfig<ReturnType>? config,
    CachedQuery? cache,
  })
  get query => QueryKey(this).query;

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
///   String keyGenerator() => 'create_user';
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
/// final result = await mutation.mutationKey.mutate();
/// ```
///
/// ## Type Parameters
/// - [RequestType]: The mutation request type (usually the implementing class)
/// - [ReturnType]: The expected return type from successful mutations
/// - [ErrorType]: Your custom error type that will be mapped to [MutationException]
abstract class MutationSerializable<RequestType extends MutationSerializable<RequestType, ReturnType, ErrorType>, ReturnType, ErrorType> {
  /// Generates a unique key for this mutation type, used for caching and identifying the mutation
  String keyGenerator();

  /// Accepts the request, error, and fallback value, then maps them to an [OnErrorResults] containing the mapped error and fallback handling
  OnErrorResults<RequestType, ReturnType?> errorMapper(RequestType request, ErrorType error, ReturnType? fallback);

  /// Accepts a dynamic response and maps it to the expected [ReturnType]
  ReturnType responseHandler(dynamic response);

  /// The core function that performs the mutation and returns a [Future] of [ReturnType]
  /// Make sure if an error is thrown it conforms to [ErrorType] for consistent error handling
  Future<ReturnType> mutationFn();

  /// Optional cache instance to use for this mutation, if none is provided. Will use the global cache
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
///   String keyGenerator() => 'users_infinite_$pageSize';
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
  /// Generates a unique key for this infinite query type, used for caching and identifying the query
  String keyGenerator();

  /// Accepts an error of type [ErrorType] and maps it to a [QueryException] for consistent error handling
  QueryException errorMapper(ErrorType error);

  /// Accepts a dynamic response and maps it to the expected [ReturnType]
  ReturnType responseHandler(dynamic response);

  /// The core function that performs the query for a specific page/chunk and returns a [Future] of [ReturnType]
  /// Takes [RequestData] (typically page number, offset, or cursor) to determine what data to fetch
  Future<ReturnType> queryFn(RequestData requestData);

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

  /// Used for persisting the infinite query data to storage, should convert [InfiniteQueryData] to a [Map<String, dynamic>]
  Map<String, dynamic> Function(InfiniteQueryData<ReturnType, RequestData>)? get storageSerializer => null;

  /// Used for retrieving the infinite query data from storage, should convert a [Map<String, dynamic>] back to [InfiniteQueryData]
  InfiniteQueryData<ReturnType, RequestData> Function(Map<String, dynamic>)? get storageDeserializer => null;

  /// Whether to store the query result in persistent storage
  /// Make sure that your storage interface has been connected and initialised before overriding this to true.
  bool get storeQuery => false;

  /// Optional cache instance to use for this query, if none is provided. Will use the global cache
  CachedQuery? get cache => null;
}

extension QuerySerializableExtension<T extends QuerySerializable<ReturnType, ErrorType>, ReturnType, ErrorType> on T {
  QueryKey<T, ReturnType, ErrorType> get queryKey => QueryKey(this);
}

extension MutationSerializableExtension<T extends MutationSerializable<T, ReturnType, ErrorType>, ReturnType, ErrorType> on T {
  MutationKey<T, ReturnType, ErrorType> get mutationKey => MutationKey(this);
}

extension InfiniteQuerySerializableExtension<
  T extends InfiniteQuerySerializable<ReturnType, RequestData, ErrorType>,
  ReturnType,
  RequestData,
  ErrorType
>
    on T {
  InfiniteQueryKey<T, ReturnType, RequestData, ErrorType> get infiniteQueryKey => InfiniteQueryKey(this);
}

class OnErrorResults<RequestType, ReturnType> {
  final RequestType request;
  final MutationException error;
  final ReturnType? fallback;
  const OnErrorResults({required this.request, required this.error, this.fallback});
}
