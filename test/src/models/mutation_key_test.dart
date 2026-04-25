import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/mutation_key.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

import '../../mocks/src/models/mutation_key_test.mocks.dart';

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

class UpdateUserRequest {
  final int id;
  final String? name;
  final String? email;

  UpdateUserRequest({required this.id, this.name, this.email});
}

// Mock Error Types
class ValidationError {
  final String field;
  final String message;
  ValidationError(this.field, this.message);
}

class NetworkError {
  final String reason;
  NetworkError(this.reason);
}

// Mock Service
abstract class MockApiService {
  Future<User> createUser(CreateUserRequest request);
  Future<User> updateUser(UpdateUserRequest request);
  Future<void> deleteUser(int id);
}

@GenerateMocks([MockApiService])
// Test Mutation Implementations
class CreateUserMutation extends MutationSerializable<CreateUserMutation, User, ValidationError> {
  final CreateUserRequest request;
  final MockApiService apiService;
  final MutationCache? _cache;

  CreateUserMutation({required this.request, required this.apiService, MutationCache? cache}) : _cache = cache;

  @override
  String get keyGenerator => 'create_user_${request.name}_${request.email}';

  @override
  OnErrorResults<CreateUserMutation, User?> errorMapper(CreateUserMutation request, ValidationError error, User? fallback) {
    return OnErrorResults(
      request: request,
      error: MutationException('Validation failed on ${error.field}: ${error.message}', 400),
      fallback: fallback,
    );
  }

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> mutationFn() => apiService.createUser(request);

  @override
  MutationCache? get cache => _cache;
}

void main() {
  late MockMockApiService mockApiService;
  late MutationCache mutationCache;

  setUp(() {
    mockApiService = MockMockApiService();
    // Create a new cache instance for each test to prevent interference
    mutationCache = MutationCache.asNewInstance();
  });

  tearDown(() {
    // No need to clear - each test uses its own cache instance
  });

  group('MutationKey Basic Functionality', () {
    test('should generate correct key from request', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = MutationKey(mutation);

      expect(mutationKey, isNotNull);
    });

    test('should return mutation key from serializable', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = mutation.mutationKey;

      expect(mutationKey, isA<MutationKey<CreateUserMutation, User, ValidationError>>());
    });

    test('should indicate mutation does not exist initially', () {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = MutationKey(mutation);

      expect(mutationKey.exists, false);
      expect(mutationKey.isPending, false);
      expect(mutationKey.isRefetching, false);
      expect(mutationKey.isError, false);
      expect(mutationKey.error, null);
    });
  });

  group('MutationKey Execution', () {
    test('should execute successful mutation', () async {
      final request = CreateUserRequest(name: 'John', email: 'john@example.com');
      final user = User(id: 1, name: 'John', email: 'john@example.com');

      when(mockApiService.createUser(request)).thenAnswer((_) async => user);

      final mutation = CreateUserMutation(request: request, apiService: mockApiService);
      final mutationKey = MutationKey(mutation);

      final result = await mutationKey.mutate();

      expect(result.data, user);
      verify(mockApiService.createUser(request)).called(1);
    });

    test('should handle validation errors correctly', () async {
      final request = CreateUserRequest(name: '', email: 'invalid-email');

      when(mockApiService.createUser(request)).thenThrow(ValidationError('email', 'Invalid email format'));

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = MutationKey(mutation);

      MutationException? capturedError;
      await mutationKey.mutate(onError: (req, error, fallback) => capturedError = error);

      expect(capturedError, isNotNull);
      expect(capturedError!.message, contains('Validation failed on email'));
      expect(capturedError!.statusCode, 400);
    });

    test('should throw MutationException for unhandled errors', () async {
      final request = CreateUserRequest(name: 'Jane', email: 'jane@example.com');

      when(mockApiService.createUser(request)).thenThrow(Exception('Database connection failed'));

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = MutationKey(mutation);

      expect(
        () => mutationKey.mutate(),
        throwsA(isA<MutationException>().having((e) => e.message, 'message', contains('An unhandled exception has taken place'))),
      );
    });
  });

  group('MutationKey Timeout Handling', () {
    test('should throw MutationException when timeout occurs and no onTimeout handler provided', () async {
      final request = CreateUserRequest(name: 'Slow', email: 'slow@example.com');

      // Simulate slow response that will timeout
      when(mockApiService.createUser(request)).thenAnswer((_) async {
        await Future<void>.delayed(Duration(seconds: 2));
        return User(id: 1, name: 'Slow', email: 'slow@example.com');
      });

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = MutationKey(mutation);

      // When no onTimeout is provided, TimeoutException becomes MutationException (fail fast)
      expect(
        () => mutationKey.mutate(timeoutSeconds: 1), // 1 second timeout, but response takes 2 seconds
        throwsA(isA<MutationException>().having((e) => e.message, 'message', contains('An unhandled exception has taken place'))),
      );
    });

    test('should call onTimeout handler when timeout occurs and onTimeout is provided', () async {
      final request = CreateUserRequest(name: 'Slow', email: 'slow@example.com');
      CreateUserMutation? timeoutRequest;

      // Simulate slow response that will timeout
      when(mockApiService.createUser(request)).thenAnswer((_) async {
        await Future<void>.delayed(Duration(seconds: 2));
        return User(id: 1, name: 'Slow', email: 'slow@example.com');
      });

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = MutationKey(mutation);

      // When onTimeout is provided, TimeoutException is rethrown → Mutation catches it → calls onTimeout
      final result = await mutationKey.mutate(
        timeoutSeconds: 1, // 1 second timeout, but response takes 2 seconds
        onTimeout: (req) => timeoutRequest = req,
      );

      // onTimeout should have been called with the mutation instance
      expect(timeoutRequest, mutation);
      // The mutation should return with whatever the onTimeout function returned (void in this case)
      expect(result.data, isNull);
    });

    test('should throw ArgumentError if onTimeout provided without timeoutSeconds', () {
      final request = CreateUserRequest(name: 'Test', email: 'test@example.com');
      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = MutationKey(mutation);

      expect(
        () => mutationKey.mutate(onTimeout: (req) => {}), // onTimeout without timeoutSeconds
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('If onTimeout is provided, timeoutSeconds must also be provided'))),
      );
    });

    test('should work normally without timeout parameters', () async {
      final request = CreateUserRequest(name: 'Normal', email: 'normal@example.com');
      final user = User(id: 1, name: 'Normal', email: 'normal@example.com');

      when(mockApiService.createUser(request)).thenAnswer((_) async => user);

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = MutationKey(mutation);

      final result = await mutationKey.mutate(); // No timeout parameters

      expect(result.data, user);
      verify(mockApiService.createUser(request)).called(1);
    });
  });

  group('MutationKey Backoff', () {
    test('uses defaultMutationBackoff when no backoff is provided', () async {
      final request = CreateUserRequest(name: 'Bo', email: 'bo@example.com');
      final user = User(id: 1, name: 'Bo', email: 'bo@example.com');
      var calls = 0;
      when(mockApiService.createUser(request)).thenAnswer((_) async {
        calls += 1;
        if (calls < 3) throw ValidationError('email', 'temporary');
        return user;
      });

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final result = await MutationKey(mutation).mutate(retryAttempts: 2, shouldRetry: (_) => true);

      expect(result.data, user);
      verify(mockApiService.createUser(request)).called(3);
    });

    test('invokes the supplied backoff function once per retry with 1-based attempt index', () async {
      final request = CreateUserRequest(name: 'Bo', email: 'bo@example.com');
      final user = User(id: 1, name: 'Bo', email: 'bo@example.com');
      var calls = 0;
      when(mockApiService.createUser(request)).thenAnswer((_) async {
        calls += 1;
        if (calls < 3) throw ValidationError('email', 'temporary');
        return user;
      });

      final invocations = <int>[];
      Duration record(int attempt) {
        invocations.add(attempt);
        return Duration.zero; // keep test fast
      }

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      await MutationKey(mutation).mutate(retryAttempts: 2, shouldRetry: (_) => true, backoff: record);

      expect(invocations, [1, 2], reason: 'backoff is called once between attempts, with a 1-based attempt index');
    });

    test('does not invoke backoff when no retry is requested', () async {
      final request = CreateUserRequest(name: 'Solo', email: 'solo@example.com');
      final user = User(id: 1, name: 'Solo', email: 'solo@example.com');
      when(mockApiService.createUser(request)).thenAnswer((_) async => user);

      var invoked = false;
      Duration record(int _) {
        invoked = true;
        return Duration.zero;
      }

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final result = await MutationKey(mutation).mutate(backoff: record);

      expect(result.data, user);
      expect(invoked, isFalse);
    });

    test('defaultMutationBackoff returns 100 ms × attempt', () {
      expect(defaultMutationBackoff(1), const Duration(milliseconds: 100));
      expect(defaultMutationBackoff(3), const Duration(milliseconds: 300));
    });
  });
}
