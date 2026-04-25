import 'package:flutter_test/flutter_test.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

import '../data/models/user.dart';
import '../data/models/create_user_request.dart';
import '../data/models/update_user_request.dart';
import '../data/models/api_error.dart';
import '../data/models/validation_error.dart';
import '../data/models/network_error.dart';
import '../data/models/mock_api_service.dart';

import '../data/models/get_user_query_request.dart';
import '../data/models/get_all_users_query_request.dart';
import '../data/models/retryable_create_user_request.dart';
import 'integration_test.mocks.dart';

@GenerateMocks([MockApiService])
void main() {
  late MockApiService mockApiService;
  late CachedQuery cachedQuery;
  late MutationCache mutationCache;

  setUp(() {
    mockApiService = MockMockApiService();
    // Create isolated cache instances for each test
    cachedQuery = CachedQuery.asNewInstance();
    mutationCache = MutationCache.asNewInstance();
  });

  tearDown(() {
    // No need to clear - each test uses its own cache instance
  });

  group('End-to-End Query Scenarios', () {
    test('should handle complete user fetch workflow', () async {
      final user = User(id: 1, name: 'John Doe', email: 'john@example.com', createdAt: DateTime.now());

      when(mockApiService.getUser(1)).thenAnswer((_) async => user);

      final query = GetUserQueryRequest(userId: 1, apiService: mockApiService, cache: cachedQuery);
      final queryKey = query.queryKey;

      // Initial state
      expect(queryKey.exists, false);
      expect(queryKey.isPending, false);
      expect(queryKey.isError, false);

      // Execute query
      final result = await queryKey.query().fetch();

      // Verify result
      expect(result.data, user);
      expect(queryKey.exists, true);
      verify(mockApiService.getUser(1)).called(1);

      // Test caching - second call should use cache
      final cachedResult = await queryKey.fetch();
      expect(cachedResult?.data, user);
      // Should still be 1 call total since second is cached
      verifyNoMoreInteractions(mockApiService);
    });

    test('should handle query error scenarios gracefully', () async {
      when(mockApiService.getUser(999)).thenThrow(ApiError('User not found', 404));

      final query = GetUserQueryRequest(userId: 999, apiService: mockApiService, cache: cachedQuery);
      final queryKey = query.queryKey;

      QueryException? capturedError;
      final queryInstance = queryKey.query(onError: (error) => capturedError = error);

      try {
        await queryInstance.fetch();
      } catch (e) {
        // Expected
      }

      expect(capturedError, isNotNull);
      expect(capturedError!.message, contains('Failed to get user'));
      expect(capturedError!.statusCode, 404);
      expect(queryKey.isError, true);
    });

    test('should handle multiple queries with different error types', () async {
      final users = [User(id: 1, name: 'John Doe', email: 'john@example.com'), User(id: 2, name: 'Jane Doe', email: 'jane@example.com')];

      when(mockApiService.getUser(1)).thenAnswer((_) async => users[0]);
      when(mockApiService.getUsers()).thenThrow(NetworkError('Connection timeout'));

      final userQuery = GetUserQueryRequest(userId: 1, apiService: mockApiService, cache: cachedQuery);
      final getUsersRequest = GetAllUsersQueryRequest(apiService: mockApiService, cache: cachedQuery);

      // User query should succeed
      final userResult = await userQuery.query().fetch();
      expect(userResult.data?.id, users[0].id);
      expect(userResult.data?.name, users[0].name);
      expect(userResult.data?.email, users[0].email);

      // Users query should fail with network error
      QueryException? usersError;
      try {
        await getUsersRequest.query(onError: (QueryException error) => usersError = error).fetch();
      } catch (e) {
        // Expected
      }

      expect(usersError, isNotNull);
      expect(usersError!.message, contains('Connection timeout'));
      expect(usersError!.statusCode, 503);
    });
  });

  group('End-to-End Mutation Scenarios', () {
    test('should handle complete user creation workflow', () async {
      final createdUser = User(id: 3, name: 'Alice', email: 'alice@example.com', createdAt: DateTime.now());
      final request = CreateUserRequest(name: 'Alice', email: 'alice@example.com', apiService: mockApiService, cache: mutationCache);

      when(mockApiService.createUser(request)).thenAnswer((_) async => createdUser);

      final mutationKey = request.mutationKey;

      // Initial state
      expect(mutationKey.exists, false);
      expect(mutationKey.isPending, false);
      expect(mutationKey.isError, false);

      // Execute mutation
      User? successResult;
      final result = await request.mutate(onSuccess: (User data, CreateUserRequest req) => successResult = data);

      // Verify result
      expect(result.data, createdUser);
      expect(successResult, createdUser);
      verify(mockApiService.createUser(request)).called(1);
    });

    test('should handle validation errors in mutations', () async {
      final request = CreateUserRequest(name: '', email: 'invalid-email', apiService: mockApiService, cache: mutationCache);

      when(mockApiService.createUser(request)).thenThrow(
        ValidationError({
          'name': ['Name cannot be empty'],
          'email': ['Invalid email format'],
        }),
      );

      MutationException? capturedError;
      CreateUserRequest? errorRequest;

      await request.mutate(
        onError: (CreateUserRequest req, MutationException error, User? fallback) {
          capturedError = error;
          errorRequest = req;
        },
      );

      expect(capturedError, isNotNull);
      expect(capturedError!.message, contains('Validation failed'));
      expect(capturedError!.message, contains('Name cannot be empty'));
      expect(capturedError!.message, contains('Invalid email format'));
      expect(capturedError!.statusCode, 400);
      expect(errorRequest, request);
    });

    test('should handle mutation retry scenarios', () async {
      final retryableRequest = RetryableCreateUserRequest(name: 'Bob', email: 'bob@example.com', apiService: mockApiService, cache: mutationCache);
      final user = User(id: 123, name: 'Bob', email: 'bob@example.com');
      // Simulate network errors followed by success
      var callCount = 0;
      when(mockApiService.createUser(any)).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as CreateUserRequest;
        callCount++;
        if (callCount == 1) throw NetworkError('Temporary network issue');
        if (callCount == 2) throw NetworkError('Still having issues');
        return User(id: 123, name: request.name, email: request.email);
      });

      final result = await retryableRequest.mutate(
        retryAttempts: 2,
        shouldRetry: (_) => true, // Retry all errors
      );

      expect(result.data, user);
      verify(mockApiService.createUser(any)).called(3); // Initial + 2 retries
    });

    test('should handle timeout scenarios', () async {
      final request = CreateUserRequest(name: 'Slow', email: 'slow@example.com', apiService: mockApiService, cache: mutationCache);

      // Simulate slow response
      when(mockApiService.createUser(request)).thenAnswer((_) async {
        await Future<void>.delayed(Duration(seconds: 5));
        return User(id: 5, name: 'Slow', email: 'slow@example.com');
      });

      CreateUserRequest? timeoutRequest;

      final result = await request.mutate(timeoutSeconds: 1, onTimeout: (CreateUserRequest req) => timeoutRequest = req);

      // onTimeout should have been called, result should be null since onTimeout returns void
      expect(timeoutRequest, request);
      expect(result.data, isNull);
    });
  });

  group('Query and Mutation Integration', () {
    test('should handle optimistic updates workflow', () async {
      final initialUser = User(id: 1, name: 'John', email: 'john@example.com');
      final updatedUser = User(id: 1, name: 'John Updated', email: 'john@example.com');

      // Setup initial query
      when(mockApiService.getUser(1)).thenAnswer((_) async => initialUser);

      final request = GetUserQueryRequest(userId: 1, apiService: mockApiService, cache: cachedQuery);
      final updateRequest = UpdateUserRequest(id: 1, name: 'John Updated', apiService: mockApiService, cache: mutationCache);

      when(mockApiService.updateUser(updateRequest)).thenAnswer((_) async => updatedUser);

      // Fetch initial data
      final initialResult = await request.query().fetch();
      expect(request.queryKey.exists, true);
      expect(initialResult.data, initialUser);

      // Perform optimistic update
      final optimisticUser = initialUser.copyWith(name: 'John Updated');
      request.queryKey.updateData((_) => optimisticUser);

      // Execute mutation
      final result = await updateRequest.mutate();

      // Manually invalidate and refetch the query after mutation
      request.queryKey.invalidate(refetchActive: true);

      expect(result.data, updatedUser);
      verify(mockApiService.updateUser(updateRequest)).called(1);
    });

    test('should handle complex error scenarios across queries and mutations', () async {
      // Setup scenarios where different components fail with different error types
      when(mockApiService.getUser(1)).thenThrow(ApiError('Database connection failed', 500));
      when(mockApiService.createUser(any)).thenThrow(
        ValidationError({
          'name': ['Name too short'],
        }),
      );

      final query = GetUserQueryRequest(userId: 1, apiService: mockApiService, cache: cachedQuery);
      final request = CreateUserRequest(name: 'A', email: 'a@example.com', apiService: mockApiService, cache: mutationCache);

      // Test query error
      QueryException? queryError;
      try {
        await query.query(onError: (QueryException error) => queryError = error).fetch();
      } catch (e) {
        // Expected
      }

      expect(queryError, isNotNull);
      expect(queryError!.statusCode, 500);

      // Test mutation error
      MutationException? mutationError;
      await request.mutate(onError: (req, error, fallback) => mutationError = error);

      expect(mutationError, isNotNull);
      expect(mutationError!.statusCode, 400);
      expect(mutationError!.message, contains('Name too short'));
    });
  });
}
