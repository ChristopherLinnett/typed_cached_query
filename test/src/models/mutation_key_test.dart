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
class _ParseFailingMutation extends MutationSerializable<_ParseFailingMutation, User, ValidationError> {
  final CreateUserRequest request;
  final MockApiService apiService;
  final MutationCache? _cache;

  _ParseFailingMutation({required this.request, required this.apiService, MutationCache? cache}) : _cache = cache;

  @override
  String get keyGenerator => 'parse_failing_${request.name}';

  @override
  OnErrorResults<_ParseFailingMutation, User?> errorMapper(_ParseFailingMutation request, ValidationError error, User? fallback) {
    return OnErrorResults(request: request, error: MutationException(error.message, 400), fallback: fallback);
  }

  @override
  User responseHandler(dynamic response) {
    throw const FormatException('responseHandler intentionally failed');
  }

  @override
  Future<dynamic> mutationFn() => apiService.createUser(request);

  @override
  MutationCache? get cache => _cache;
}

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

      expect(mutation.mutationKey, isNotNull);
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
      final mutationKey = mutation.mutationKey;

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

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);

      final result = await mutation.mutate();

      expect(result.data, user);
      verify(mockApiService.createUser(request)).called(1);
    });

    test('should handle validation errors correctly', () async {
      final request = CreateUserRequest(name: '', email: 'invalid-email');

      when(mockApiService.createUser(request)).thenThrow(ValidationError('email', 'Invalid email format'));

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);

      MutationException? capturedError;
      await mutation.mutate(onError: (req, error, fallback) => capturedError = error);

      expect(capturedError, isNotNull);
      expect(capturedError!.message, contains('Validation failed on email'));
      expect(capturedError!.statusCode, 400);
    });

    test('should throw MutationException for unhandled errors', () async {
      final request = CreateUserRequest(name: 'Jane', email: 'jane@example.com');

      when(mockApiService.createUser(request)).thenThrow(Exception('Database connection failed'));

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);

      expect(
        () => mutation.mutate(),
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

      // When no onTimeout is provided, TimeoutException becomes MutationException (fail fast)
      expect(
        () => mutation.mutate(timeoutSeconds: 1), // 1 second timeout, but response takes 2 seconds
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

      // When onTimeout is provided, TimeoutException is rethrown → Mutation catches it → calls onTimeout
      final result = await mutation.mutate(
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

      expect(
        () => mutation.mutate(onTimeout: (req) => {}), // onTimeout without timeoutSeconds
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('If onTimeout is provided, timeoutSeconds must also be provided'))),
      );
    });

    test('should work normally without timeout parameters', () async {
      final request = CreateUserRequest(name: 'Normal', email: 'normal@example.com');
      final user = User(id: 1, name: 'Normal', email: 'normal@example.com');

      when(mockApiService.createUser(request)).thenAnswer((_) async => user);

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);

      final result = await mutation.mutate(); // No timeout parameters

      expect(result.data, user);
      verify(mockApiService.createUser(request)).called(1);
    });
  });

  group('MutationKey error getter', () {
    test('returns null when state is not in error', () async {
      final request = CreateUserRequest(name: 'OK', email: 'ok@example.com');
      final user = User(id: 1, name: 'OK', email: 'ok@example.com');
      when(mockApiService.createUser(request)).thenAnswer((_) async => user);

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = mutation.mutationKey;
      await mutation.mutate();

      expect(mutationKey.isError, isFalse);
      expect(mutationKey.error, isNull, reason: 'error must mirror isError — never returns a value when isError is false');
    });

    test('maps a stored ErrorType via errorMapper', () async {
      final request = CreateUserRequest(name: 'Bad', email: 'bad@example.com');
      when(mockApiService.createUser(request)).thenThrow(ValidationError('email', 'taken'));

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = mutation.mutationKey;
      // mutate does NOT throw for ErrorType — it maps via errorMapper and surfaces via state.
      await mutation.mutate();

      expect(mutationKey.isError, isTrue);
      final err = mutationKey.error;
      expect(err, isA<MutationException>());
      expect(err!.message, contains('Validation failed on email'));
    });

    // Note: the MutationKey 'unknown stored error' fallback branch (status 500 'Unhandled error:'
    // path) is intentionally NOT covered here. When mutationFn throws a non-ErrorType, the wrapper
    // throws MutationException internally and cached_query leaves the mutation in an in-flight
    // (isMutating=true) state rather than transitioning to MutationError, so .error returns null
    // regardless of getter implementation. The analogous fallback in QueryKey.error and
    // InfiniteQueryKey.error IS covered by their respective test groups, which lock in the
    // shared branch logic.

    test('returns null after a successful mutate following a prior failure (regression: stale-error guard)', () async {
      // Pre-#102: state.error could remain non-null on a non-error state, so .error returned a
      // value while .isError was false. Run a failing mutate, then a successful one on the same
      // mutation, and assert .error mirrors isError and is null.
      final request = CreateUserRequest(name: 'Flip', email: 'flip@example.com');
      when(mockApiService.createUser(request)).thenThrow(ValidationError('email', 'taken'));

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final mutationKey = mutation.mutationKey;
      await mutation.mutate();
      expect(mutationKey.isError, isTrue);

      reset(mockApiService);
      when(mockApiService.createUser(request)).thenAnswer((_) async => User(id: 9, name: 'Flip', email: 'flip@example.com'));
      await mutation.mutate();

      expect(mutationKey.isError, isFalse, reason: 'after a successful mutate the wrapper must report not-error');
      expect(mutationKey.error, isNull, reason: 'after a successful mutate .error must mirror isError and be null');
    });
  });

  group('MutationKey Backoff', () {
    test('retries succeed when no backoff is provided', () async {
      final request = CreateUserRequest(name: 'Bo', email: 'bo@example.com');
      final user = User(id: 1, name: 'Bo', email: 'bo@example.com');
      var calls = 0;
      when(mockApiService.createUser(request)).thenAnswer((_) async {
        calls += 1;
        if (calls < 3) throw ValidationError('email', 'temporary');
        return user;
      });

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      final result = await mutation.mutate(retryAttempts: 2, shouldRetry: (_) => true);

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
      await mutation.mutate(retryAttempts: 2, shouldRetry: (_) => true, backoff: record);

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
      final result = await mutation.mutate(backoff: record);

      expect(result.data, user);
      expect(invoked, isFalse);
    });

    test('defaultMutationBackoff returns 100 ms × attempt', () {
      expect(defaultMutationBackoff(1), const Duration(milliseconds: 100));
      expect(defaultMutationBackoff(3), const Duration(milliseconds: 300));
    });
  });

  group('MutationSerializable.mutate convenience getter', () {
    test('serializable.mutate(...) executes the same pipeline as the previous mutationKey.mutate', () async {
      final request = CreateUserRequest(name: 'Bo', email: 'bo@example.com');
      final user = User(id: 7, name: 'Bo', email: 'bo@example.com');
      when(mockApiService.createUser(request)).thenAnswer((_) async => user);

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      // No `.mutationKey` chain — this is the new public entry point.
      final result = await mutation.mutate();

      expect(result.data, user);
      verify(mockApiService.createUser(request)).called(1);
    });

    test('serializable.mutate(...) forwards optional parameters (onError)', () async {
      final request = CreateUserRequest(name: 'Forwarded', email: 'f@b.c');
      when(mockApiService.createUser(request)).thenThrow(ValidationError('email', 'taken'));

      final mutation = CreateUserMutation(request: request, apiService: mockApiService, cache: mutationCache);
      MutationException? captured;
      await mutation.mutate(onError: (req, err, fb) => captured = err);

      expect(captured, isA<MutationException>());
      expect(captured!.statusCode, 400);
    });
  });

  group('MutationKey responseHandler error wrapping', () {
    test('responseHandler exception is wrapped as MutationException(400) and not retried', () async {
      final request = CreateUserRequest(name: 'Bo', email: 'bo@example.com');
      var attempts = 0;
      when(mockApiService.createUser(request)).thenAnswer((_) async {
        attempts += 1;
        return User(id: 1, name: 'Bo', email: 'bo@example.com');
      });

      // Subclass the existing fixture so its responseHandler always throws.
      final mutation = _ParseFailingMutation(request: request, apiService: mockApiService, cache: mutationCache);

      Object? thrown;
      try {
        await mutation.mutate(
          retryAttempts: 3,
          shouldRetry: (_) => true,
        );
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isA<MutationException>());
      expect((thrown as MutationException).statusCode, 400, reason: 'parsing errors must surface as a 400 — same shape as QueryKey/InfiniteQueryKey');
      expect(thrown.message, contains('parsing the response'));
      // Parse failures are NOT retryable — only ErrorType failures are.
      expect(attempts, 1, reason: 'a parse failure must NOT be retried, even when retryAttempts/shouldRetry are set');
    });
  });

  group('MutationKey responseHandler wiring', () {
    test('mutationFn raw output is passed through responseHandler before reaching the caller', () async {
      // Use a fixture whose mutationFn returns a raw Map and whose responseHandler reconstructs
      // a User with a sentinel suffix. If responseHandler were bypassed, result.data would be the
      // raw Map (not a User) and the assertions would fail.
      final mutation = _MapMutation(returnRaw: {'id': 7, 'name': 'Raw', 'email': 'raw@example.com'}, cache: mutationCache);
      final result = await mutation.mutate();

      expect(result.data, isA<User>(), reason: 'mutate result must be the User produced by responseHandler, not the raw Map from mutationFn');
      expect(result.data!.name, endsWith('-via-responseHandler'), reason: 'sentinel suffix proves responseHandler ran');
    });
  });
}

/// Fixture for the responseHandler-wiring test: raw mutationFn returns a Map and responseHandler
/// reconstructs a User with a sentinel suffix so the wiring is *observable* — bypassing
/// responseHandler would leave result.data as the raw Map.
class _MapMutation extends MutationSerializable<_MapMutation, User, ValidationError> {
  final Map<String, dynamic> returnRaw;
  final MutationCache? _cache;

  _MapMutation({required this.returnRaw, MutationCache? cache}) : _cache = cache;

  @override
  String get keyGenerator => 'map_mutation';

  @override
  OnErrorResults<_MapMutation, User?> errorMapper(_MapMutation request, ValidationError error, User? fallback) =>
      OnErrorResults(request: request, error: MutationException(error.message, 400), fallback: fallback);

  @override
  User responseHandler(dynamic response) {
    final map = response as Map<String, dynamic>;
    return User(id: map['id'] as int, name: '${map['name']}-via-responseHandler', email: map['email'] as String);
  }

  @override
  Future<dynamic> mutationFn() async => returnRaw;

  @override
  MutationCache? get cache => _cache;
}
