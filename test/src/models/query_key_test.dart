import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/query_key.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

import '../../mocks/src/models/query_key_test.mocks.dart';

// Mock Data Models
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  factory User.fromJson(Map<String, dynamic> json) => User(id: json['id'] as int, name: json['name'] as String, email: json['email'] as String);

  @override
  bool operator ==(Object other) => identical(this, other) || other is User && id == other.id && name == other.name && email == other.email;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;
}

// Mock Error Types
class ApiError {
  final String message;
  final int code;
  ApiError(this.message, this.code);
}

class NetworkError {
  final String reason;
  NetworkError(this.reason);
}

// Mock Service
abstract class MockApiService {
  Future<User> getUser(int id);
  Future<List<User>> getUsers();
}

@GenerateMocks([MockApiService])
// Test Query Implementation
class GetUserQuery extends QuerySerializable<User, ApiError> {
  final int userId;
  final MockApiService apiService;
  final CachedQuery localCache;

  GetUserQuery({required this.userId, required this.apiService, required this.localCache});

  @override
  Map<String, dynamic> toJson() => {'userId': userId};

  @override
  QueryException errorMapper(ApiError error) => QueryException('API Error: ${error.message}', error.code);

  @override
  User responseHandler(dynamic response) {
    if (response is Map<String, dynamic>) {
      return User.fromJson(response);
    }
    return response as User;
  }

  @override
  CachedQuery get cache => localCache;

  @override
  Future<User> queryFn() => apiService.getUser(userId);

  @override
  Map<String, dynamic> Function(User)? get storageSerializer =>
      (user) => user.toJson();

  @override
  User Function(Map<String, dynamic>)? get storageDeserializer => User.fromJson;

  @override
  bool get storeQuery => true;
}

class GetUsersQuery extends QuerySerializable<List<User>, NetworkError> {
  final MockApiService apiService;

  GetUsersQuery({required this.apiService});

  @override
  Map<String, dynamic> toJson() => {};

  @override
  QueryException errorMapper(NetworkError error) => QueryException('Network Error: ${error.reason}', 503);

  @override
  List<User> responseHandler(dynamic response) {
    if (response is List) {
      return response.map((item) => item is Map<String, dynamic> ? User.fromJson(item) : item as User).toList();
    }
    return response as List<User>;
  }

  @override
  Future<List<User>> queryFn() => apiService.getUsers();

  @override
  Map<String, dynamic> Function(List<User>)? get storageSerializer => null;

  @override
  List<User> Function(Map<String, dynamic>)? get storageDeserializer => null;

  @override
  bool get storeQuery => false;
}

void main() {
  late MockMockApiService mockApiService;
  late CachedQuery cachedQuery;

  setUp(() {
    mockApiService = MockMockApiService();
    cachedQuery = CachedQuery.asNewInstance();
  });

  tearDown(() {
    // Reset any state if needed
  });

  group('QueryKey Basic Functionality', () {
    test('should generate correct key from request', () {
      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);

      expect(queryKey.rawKey, 'GetUserQuery-{userId: 123}');
    });

    test('should return query key from serializable', () {
      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = request.queryKey;

      expect(queryKey, isA<QueryKey<GetUserQuery, User, ApiError>>());
      expect(queryKey.rawKey, 'GetUserQuery-{userId: 123}');
    });

    test('should indicate query does not exist initially', () {
      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);

      expect(queryKey.exists, false);
      expect(queryKey.isPending, false);
      expect(queryKey.isRefetching, false);
      expect(queryKey.isError, false);
      expect(queryKey.error, null);
    });
  });

  group('QueryKey Query Execution', () {
    test('should execute successful query', () async {
      final user = User(id: 123, name: 'John Doe', email: 'john@example.com');
      when(mockApiService.getUser(123)).thenAnswer((_) async => user);

      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);
      final query = queryKey.query();

      final result = await query.fetch();

      expect(result.data, user);
      verify(mockApiService.getUser(123)).called(1);
    });

    test('should handle API errors correctly', () async {
      when(mockApiService.getUser(456)).thenThrow(ApiError('User not found', 404));

      final request = GetUserQuery(userId: 456, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);

      QueryException? capturedError;
      final query = queryKey.query(onError: (error) => capturedError = error);

      try {
        await query.fetch();
      } catch (e) {
        // Expected to throw
      }

      expect(capturedError, isNotNull);
      expect(capturedError!.message, 'API Error: User not found');
      expect(capturedError!.statusCode, 404);
    });

    test('should throw QueryException for unhandled errors', () async {
      when(mockApiService.getUser(789)).thenThrow(Exception('Unexpected error'));

      final request = GetUserQuery(userId: 789, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);
      final query = queryKey.query();

      expect(
        () => query.fetch(),
        throwsA(isA<QueryException>().having((e) => e.message, 'message', contains('An unhandled exception has taken place'))),
      );
    });

    test('FormatException message names the actual ReturnType (not the literal "Type")', () async {
      final user = User(id: 1, name: 'A', email: 'a@b.c');
      when(mockApiService.getUser(1)).thenAnswer((_) async => user);

      final request = _BadResponseQuery(apiService: mockApiService, localCache: cachedQuery);
      final query = request.queryKey.query();

      Object? captured;
      try {
        await query.fetch();
      } catch (e) {
        captured = e;
      }
      final stateError = query.state.error ?? captured;

      expect(stateError, isNotNull, reason: 'expected an error to be recorded for the failed responseHandler');
      final message = stateError.toString();
      expect(message, contains('to User failed'), reason: 'expected the actual ReturnType name in the FormatException message, got: $message');
      expect(message, isNot(contains('to Type failed')), reason: 'message must not contain the literal "Type"');
    });

    test('should call onSuccess callback on successful fetch', () async {
      final user = User(id: 123, name: 'John Doe', email: 'john@example.com');
      when(mockApiService.getUser(123)).thenAnswer((_) async => user);

      User? successResult;
      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);
      final query = queryKey.query(onSuccess: (data) => successResult = data);

      await query.fetch();

      expect(successResult, user);
    });
  });

  group('QueryKey Storage Configuration', () {
    test('should throw error when storeQuery is true but no serializer', () {
      final badRequest = _GetUserQueryNoSerializer(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(badRequest);

      expect(() => queryKey.query(config: QueryConfig()), throwsA(isA<ArgumentError>()));
    });

    test('should merge storage config correctly', () {
      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);

      // Should not throw since serializer is provided
      expect(() => queryKey.query(config: QueryConfig(staleDuration: Duration(minutes: 10))), returnsNormally);
    });

    test('should handle queries without storage', () {
      final request = GetUsersQuery(apiService: mockApiService);
      final queryKey = QueryKey(request);

      // Should not throw even with config since storeQuery is false
      expect(() => queryKey.query(config: QueryConfig()), returnsNormally);
    });
  });

  group('QueryKey Data Management', () {
    test('should update data correctly', () async {
      final user = User(id: 123, name: 'John Doe', email: 'john@example.com');
      when(mockApiService.getUser(123)).thenAnswer((_) async => user);

      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);
      final query = queryKey.query();

      // Initial fetch
      await query.fetch();

      // Update data
      final updatedUser = User(id: 123, name: 'Jane Doe', email: 'jane@example.com');
      final result = queryKey.updateData<User>((existingData) => updatedUser);

      expect(result, updatedUser);
    });

    test('should handle updateData with no existing query', () async {
      final request = GetUserQuery(userId: 999, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);

      final newUser = User(id: 123, name: 'New User', email: 'new@example.com');
      final result = queryKey.updateData<User>((existingData) {
        expect(existingData, null);
        return newUser;
      });

      expect(result, newUser);
    });

    test('updateData invokes the user function exactly once (existing data path)', () async {
      final user = User(id: 1, name: 'A', email: 'a@b.c');
      when(mockApiService.getUser(1)).thenAnswer((_) async => user);

      final request = GetUserQuery(userId: 1, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);
      await queryKey.query().fetch();

      var calls = 0;
      queryKey.updateData<User>((existingData) {
        calls += 1;
        return User(id: existingData!.id, name: '${existingData.name}!', email: existingData.email);
      });

      expect(calls, 1, reason: 'updateFunction must be invoked exactly once per updateData call');
    });

    test('updateData invokes the user function exactly once (no existing data path)', () async {
      final request = GetUserQuery(userId: 2, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);

      var calls = 0;
      queryKey.updateData<User>((existingData) {
        calls += 1;
        return User(id: 2, name: 'New', email: 'n@b.c');
      });

      expect(calls, 1);
    });

    test('should invalidate query correctly', () async {
      final user = User(id: 123, name: 'John Doe', email: 'john@example.com');
      when(mockApiService.getUser(123)).thenAnswer((_) async => user);

      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);
      final query = queryKey.query();

      await query.fetch();
      expect(queryKey.exists, true);

      // Invalidate should work without throwing
      expect(() => queryKey.invalidate(), returnsNormally);
    });

    test('should handle fetch function correctly', () async {
      final user = User(id: 123, name: 'John Doe', email: 'john@example.com');
      when(mockApiService.getUser(123)).thenAnswer((_) async => user);

      final request = GetUserQuery(userId: 123, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);
      final query = queryKey.query();

      await query.fetch();

      final fetchFunction = queryKey.fetch;
      final result = await fetchFunction();

      expect(result?.data, user);
    });

    test('should return null when fetching non-existent query', () async {
      final request = GetUserQuery(userId: 888, apiService: mockApiService, localCache: cachedQuery);
      final queryKey = QueryKey(request);

      final fetchFunction = queryKey.fetch;
      final result = await fetchFunction();

      expect(result, null);
    });
  });
}

// Helper that always fails inside responseHandler to exercise the FormatException path
class _BadResponseQuery extends QuerySerializable<User, ApiError> {
  final MockApiService apiService;
  final CachedQuery localCache;

  _BadResponseQuery({required this.apiService, required this.localCache});

  @override
  Map<String, dynamic> toJson() => {'id': 1};

  @override
  CachedQuery get cache => localCache;

  @override
  QueryException errorMapper(ApiError error) => QueryException(error.message, error.code);

  @override
  Future<dynamic> queryFn() => apiService.getUser(1);

  @override
  User responseHandler(dynamic response) => throw Exception('responseHandler intentionally failed');
}

// Helper class for testing error scenarios
class _GetUserQueryNoSerializer extends QuerySerializable<User, ApiError> {
  final int userId;
  final MockApiService apiService;
  final CachedQuery localCache;

  _GetUserQueryNoSerializer({required this.userId, required this.apiService, required this.localCache});

  @override
  CachedQuery get cache => localCache;

  @override
  Map<String, dynamic> toJson() => {'userId': userId};

  @override
  QueryException errorMapper(ApiError error) => QueryException('API Error: ${error.message}', error.code);

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> queryFn() => apiService.getUser(userId);

  @override
  Map<String, dynamic> Function(User)? get storageSerializer => null; // Intentionally null

  @override
  User Function(Map<String, dynamic>)? get storageDeserializer => null;

  @override
  bool get storeQuery => true; // This should cause an error
}
