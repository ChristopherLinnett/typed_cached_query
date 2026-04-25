import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/models/serializable.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';

// Mock Data Models
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  @override
  bool operator ==(Object other) => identical(this, other) || other is User && id == other.id && name == other.name && email == other.email;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;
}

class CreateUserRequest {
  final String name;
  final String email;

  CreateUserRequest({required this.name, required this.email});
}

// Mock Error Types
class ApiError {
  final String message;
  final int code;
  ApiError(this.message, this.code);
}

// Mock Storage Data Repository for Testing Serialization
class MockDataStore {
  final Map<String, Map<String, dynamic>> _data = {};

  void store(String key, Map<String, dynamic> data) {
    _data[key] = Map.from(data);
  }

  Map<String, dynamic>? retrieve(String key) {
    return _data[key];
  }

  void clear() {
    _data.clear();
  }

  int get size => _data.length;
}

// Test Implementations
class TestQuerySerializable extends QuerySerializable<User, ApiError> {
  final int userId;
  final CachedQuery? _cache;

  TestQuerySerializable({required this.userId, CachedQuery? cache}) : _cache = cache;

  @override
  Map<String, dynamic> toJson() => {'userId': userId};

  @override
  QueryException errorMapper(ApiError error) => QueryException('Test error: ${error.message}', error.code);

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> queryFn() async => User(id: userId, name: 'Test User', email: 'test@example.com');

  @override
  Map<String, dynamic> Function(User)? get storageSerializer =>
      (user) => {'id': user.id, 'name': user.name, 'email': user.email};

  @override
  User Function(Map<String, dynamic>)? get storageDeserializer =>
      (json) => User(id: json['id'] as int, name: json['name'] as String, email: json['email'] as String);

  @override
  bool get storeQuery => true;

  @override
  CachedQuery? get cache => _cache;
}

class TestMutationSerializable extends MutationSerializable<TestMutationSerializable, User, ApiError> {
  final CreateUserRequest request;

  TestMutationSerializable({required this.request});

  @override
  String get keyGenerator => 'test_create_user_${request.name}';

  @override
  OnErrorResults<TestMutationSerializable, User?> errorMapper(TestMutationSerializable request, ApiError error, User? fallback) {
    return OnErrorResults(request: request, error: MutationException('Test mutation error: ${error.message}', error.code), fallback: fallback);
  }

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> mutationFn() async => User(id: 1, name: request.name, email: request.email);
}

void main() {
  group('QuerySerializable Tests', () {
    test('should generate query key correctly', () {
      final querySerializable = TestQuerySerializable(userId: 123);

      expect(querySerializable.keyGenerator, 'TestQuerySerializable-{userId: 123}');
    });

    test('should map errors correctly', () {
      final querySerializable = TestQuerySerializable(userId: 123);
      final apiError = ApiError('User not found', 404);

      final queryException = querySerializable.errorMapper(apiError);

      expect(queryException.message, 'Test error: User not found');
      expect(queryException.statusCode, 404);
    });

    test('should handle response correctly', () {
      final querySerializable = TestQuerySerializable(userId: 123);
      final user = User(id: 123, name: 'Test User', email: 'test@example.com');

      final result = querySerializable.responseHandler(user);

      expect(result, user);
    });

    test('should execute query function', () async {
      final querySerializable = TestQuerySerializable(userId: 123);

      final result = await querySerializable.queryFn();

      expect(result.id, 123);
      expect(result.name, 'Test User');
      expect(result.email, 'test@example.com');
    });

    test('should provide storage serialization', () {
      final querySerializable = TestQuerySerializable(userId: 123);
      final user = User(id: 123, name: 'Test User', email: 'test@example.com');

      final serializer = querySerializable.storageSerializer;
      expect(serializer, isNotNull);

      final serialized = serializer!(user);
      expect(serialized['id'], 123);
      expect(serialized['name'], 'Test User');
      expect(serialized['email'], 'test@example.com');
    });

    test('should provide storage deserialization', () {
      final querySerializable = TestQuerySerializable(userId: 123);
      final json = {'id': 123, 'name': 'Test User', 'email': 'test@example.com'};

      final deserializer = querySerializable.storageDeserializer;
      expect(deserializer, isNotNull);

      final user = deserializer!(json);
      expect(user.id, 123);
      expect(user.name, 'Test User');
      expect(user.email, 'test@example.com');
    });

    test('should provide query key property', () {
      final querySerializable = TestQuerySerializable(userId: 123);

      final queryKey = querySerializable.queryKey;

      expect(queryKey, isNotNull);
      expect(queryKey.rawKey, 'TestQuerySerializable-{userId: 123}');
    });

    test('should handle storeQuery property', () {
      final querySerializable = TestQuerySerializable(userId: 123);

      expect(querySerializable.storeQuery, true);
    });
  });

  group('MutationSerializable Tests', () {
    test('should generate mutation key correctly', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);

      expect(mutationSerializable.keyGenerator, 'test_create_user_John');
    });

    test('keyGenerator is a getter (contract — same shape as QuerySerializable)', () {
      // If keyGenerator regresses to a method form, this static-typed access would not compile.
      final request = CreateUserRequest(name: 'A', email: 'a@b.c');
      final m = TestMutationSerializable(request: request);
      final String key = m.keyGenerator;
      expect(key, isNotEmpty);
    });

    test('should map errors correctly', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);
      final apiError = ApiError('Validation failed', 400);

      final result = mutationSerializable.errorMapper(mutationSerializable, apiError, null);

      expect(result.request, mutationSerializable);
      expect(result.error.message, 'Test mutation error: Validation failed');
      expect(result.error.statusCode, 400);
      expect(result.fallback, null);
    });

    test('should map errors with fallback', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);
      final apiError = ApiError('Partial failure', 206);
      final fallbackUser = User(id: 0, name: 'Fallback', email: 'fallback@example.com');

      final result = mutationSerializable.errorMapper(mutationSerializable, apiError, fallbackUser);

      expect(result.request, mutationSerializable);
      expect(result.error.message, 'Test mutation error: Partial failure');
      expect(result.error.statusCode, 206);
      expect(result.fallback, fallbackUser);
    });

    test('should handle response correctly', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);
      final user = User(id: 1, name: 'John', email: 'john@example.com');

      final result = mutationSerializable.responseHandler(user);

      expect(result, user);
    });

    test('should execute mutation function', () async {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);

      final result = await mutationSerializable.mutationFn();

      expect(result.id, 1);
      expect(result.name, 'John');
      expect(result.email, 'john@example.com');
    });

    test('should provide mutation key property', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);

      final mutationKey = mutationSerializable.mutationKey;

      expect(mutationKey, isNotNull);
    });
  });

  group('OnErrorResults Tests', () {
    test('should create OnErrorResults with all properties', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);
      final error = MutationException('Test error', 500);
      final fallback = User(id: 0, name: 'Fallback', email: 'fallback@example.com');

      final result = OnErrorResults(request: mutationSerializable, error: error, fallback: fallback);

      expect(result.request, mutationSerializable);
      expect(result.error, error);
      expect(result.fallback, fallback);
    });

    test('should create OnErrorResults with null fallback', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);
      final error = MutationException('Test error', 500);

      final result = OnErrorResults<TestMutationSerializable, User?>(request: mutationSerializable, error: error, fallback: null);

      expect(result.request, mutationSerializable);
      expect(result.error, error);
      expect(result.fallback, null);
    });

    test('OnErrorResults stores fields by reference without copying', () {
      final request = CreateUserRequest(name: 'A', email: 'a@b.c');
      final mutationSerializable = TestMutationSerializable(request: request);
      final error = MutationException('e', 500);
      final fallback = User(id: 1, name: 'F', email: 'f@b.c');

      final result = OnErrorResults(request: mutationSerializable, error: error, fallback: fallback);

      // Identity holds — fields are not copied or replaced after construction.
      expect(identical(result.request, mutationSerializable), isTrue);
      expect(identical(result.error, error), isTrue);
      expect(identical(result.fallback, fallback), isTrue);
    });
  });

  group('Serializable Integration Tests', () {
    test('should work together in query workflow', () async {
      final querySerializable = TestQuerySerializable(userId: 456);

      // Test full workflow
      final key = querySerializable.keyGenerator;
      final queryResult = await querySerializable.queryFn();
      final processedResult = querySerializable.responseHandler(queryResult);

      expect(key, 'TestQuerySerializable-{userId: 456}');
      expect(processedResult.id, 456);
      expect(processedResult.name, 'Test User');

      // Test serialization roundtrip
      final serializer = querySerializable.storageSerializer!;
      final deserializer = querySerializable.storageDeserializer!;

      final serialized = serializer(processedResult);
      final deserialized = deserializer(serialized);

      expect(deserialized, processedResult);
    });

    test('should work together in mutation workflow', () async {
      final request = CreateUserRequest(name: 'Jane', email: 'jane@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);

      // Test full workflow
      final key = mutationSerializable.keyGenerator;
      final mutationResult = await mutationSerializable.mutationFn();
      final processedResult = mutationSerializable.responseHandler(mutationResult);

      expect(key, 'test_create_user_Jane');
      expect(processedResult.name, 'Jane');
      expect(processedResult.email, 'jane@example.com');

      // Test error mapping
      final apiError = ApiError('Email already exists', 409);
      final errorResult = mutationSerializable.errorMapper(mutationSerializable, apiError, null);

      expect(errorResult.error.message, 'Test mutation error: Email already exists');
      expect(errorResult.error.statusCode, 409);
    });

    test('should maintain type safety across all operations', () {
      final querySerializable = TestQuerySerializable(userId: 789);
      final request = CreateUserRequest(name: 'Bob', email: 'bob@example.com');
      final mutationSerializable = TestMutationSerializable(request: request);

      // Test that generics are properly constrained
      expect(querySerializable, isA<QuerySerializable<User, ApiError>>());
      expect(mutationSerializable, isA<MutationSerializable<TestMutationSerializable, User, ApiError>>());

      // Test that key properties work
      expect(querySerializable.queryKey, isNotNull);
      expect(mutationSerializable.mutationKey, isNotNull);
    });
  });

  group('Serialization Integration Tests', () {
    late MockDataStore dataStore;
    late CachedQuery cachedQuery;

    setUp(() {
      dataStore = MockDataStore();
      cachedQuery = CachedQuery.asNewInstance();
    });

    tearDown(() {
      dataStore.clear();
      cachedQuery.deleteCache();
    });

    test('should serialize and deserialize query data correctly', () async {
      final querySerializable = TestQuerySerializable(userId: 999, cache: cachedQuery);
      
      // Execute query to get result
      final result = await querySerializable.queryFn();
      expect(result.id, 999);
      expect(result.name, 'Test User');

      // Test serialization
      final serializer = querySerializable.storageSerializer;
      expect(serializer, isNotNull);
      
      final serializedData = serializer!(result);
      expect(serializedData['id'], 999);
      expect(serializedData['name'], 'Test User');
      expect(serializedData['email'], 'test@example.com');

      // Store in mock storage
      final key = querySerializable.keyGenerator;
      dataStore.store(key, serializedData);

      // Test deserialization
      final retrievedData = dataStore.retrieve(key);
      expect(retrievedData, isNotNull);

      final deserializer = querySerializable.storageDeserializer;
      expect(deserializer, isNotNull);

      final deserializedUser = deserializer!(retrievedData!);
      expect(deserializedUser.id, result.id);
      expect(deserializedUser.name, result.name);
      expect(deserializedUser.email, result.email);
    });

    test('should handle multiple serializations with different data', () async {
      final List<TestQuerySerializable> queries = [];
      final List<User> originalUsers = [];

      // Create and execute multiple queries
      for (int i = 1; i <= 3; i++) {
        final querySerializable = TestQuerySerializable(userId: i * 100, cache: cachedQuery);
        queries.add(querySerializable);
        
        final user = await querySerializable.queryFn();
        originalUsers.add(user);

        // Serialize and store
        final serializer = querySerializable.storageSerializer!;
        final serializedData = serializer(user);
        dataStore.store(querySerializable.keyGenerator, serializedData);
      }

      expect(dataStore.size, 3);

      // Retrieve and deserialize all
      for (int i = 0; i < queries.length; i++) {
        final query = queries[i];
        final originalUser = originalUsers[i];
        
        final retrievedData = dataStore.retrieve(query.keyGenerator);
        expect(retrievedData, isNotNull);

        final deserializer = query.storageDeserializer!;
        final deserializedUser = deserializer(retrievedData!);
        
        expect(deserializedUser.id, originalUser.id);
        expect(deserializedUser.name, originalUser.name);
        expect(deserializedUser.email, originalUser.email);
      }
    });

    test('should handle queries without storage enabled', () {
      final querySerializableNoStorage = TestQuerySerializableNoStorage(userId: 777, cache: cachedQuery);
      
      // Serializers should be null
      expect(querySerializableNoStorage.storageSerializer, isNull);
      expect(querySerializableNoStorage.storageDeserializer, isNull);
      expect(querySerializableNoStorage.storeQuery, false);

      // Query should still work
      expect(() async => await querySerializableNoStorage.queryFn(), returnsNormally);
    });

    test('should generate consistent keys for serialization', () {
      final query1 = TestQuerySerializable(userId: 456, cache: cachedQuery);
      final query2 = TestQuerySerializable(userId: 456, cache: cachedQuery);
      final query3 = TestQuerySerializable(userId: 789, cache: cachedQuery);

      // Same data should generate same keys
      expect(query1.keyGenerator, query2.keyGenerator);
      expect(query1.keyGenerator, 'TestQuerySerializable-{userId: 456}');
      
      // Different data should generate different keys
      expect(query1.keyGenerator, isNot(query3.keyGenerator));
      expect(query3.keyGenerator, 'TestQuerySerializable-{userId: 789}');
    });

    test('should handle serialization roundtrip with complex data', () async {
      final querySerializable = TestQuerySerializable(userId: 12345, cache: cachedQuery);
      
      // Create user with complex data
      final originalUser = User(id: 12345, name: 'Complex User Name With Spaces', email: 'complex.email+test@example.com');
      
      // Serialize
      final serializer = querySerializable.storageSerializer!;
      final serializedData = serializer(originalUser);
      
      // Store and retrieve
      dataStore.store('test_complex', serializedData);
      final retrievedData = dataStore.retrieve('test_complex');
      expect(retrievedData, isNotNull);
      
      // Deserialize
      final deserializer = querySerializable.storageDeserializer!;
      final deserializedUser = deserializer(retrievedData!);
      
      // Verify exact match
      expect(deserializedUser.id, originalUser.id);
      expect(deserializedUser.name, originalUser.name);
      expect(deserializedUser.email, originalUser.email);
      expect(deserializedUser, originalUser); // Test equality operator
    });
  });
}

// Test class without storage enabled
class TestQuerySerializableNoStorage extends QuerySerializable<User, ApiError> {
  final int userId;
  final CachedQuery? _cache;

  TestQuerySerializableNoStorage({required this.userId, CachedQuery? cache}) : _cache = cache;

  @override
  Map<String, dynamic> toJson() => {'userId': userId};

  @override
  QueryException errorMapper(ApiError error) => QueryException('Test error: ${error.message}', error.code);

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> queryFn() async => User(id: userId, name: 'Test User', email: 'test@example.com');

  @override
  Map<String, dynamic> Function(User)? get storageSerializer => null;

  @override
  User Function(Map<String, dynamic>)? get storageDeserializer => null;

  @override
  bool get storeQuery => false; // Storage disabled

  @override
  CachedQuery? get cache => _cache;
}
