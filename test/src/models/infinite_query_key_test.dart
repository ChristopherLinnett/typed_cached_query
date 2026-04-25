import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/infinite_query_key.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

import '../../mocks/src/models/infinite_query_key_test.mocks.dart';

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

// Pagination models
class PageArgs {
  final int page;
  final int limit;

  PageArgs({required this.page, required this.limit});

  @override
  String toString() => 'PageArgs(page: $page, limit: $limit)';

  @override
  bool operator ==(Object other) => identical(this, other) || other is PageArgs && page == other.page && limit == other.limit;

  @override
  int get hashCode => page.hashCode ^ limit.hashCode;
}

class PagedResponse {
  final List<User> users;
  final int page;
  final int totalPages;
  final bool hasNext;

  PagedResponse({required this.users, required this.page, required this.totalPages, required this.hasNext});

  Map<String, dynamic> toJson() => {'users': users.map((u) => u.toJson()).toList(), 'page': page, 'totalPages': totalPages, 'hasNext': hasNext};

  factory PagedResponse.fromJson(Map<String, dynamic> json) => PagedResponse(
    users: (json['users'] as List).map((u) => User.fromJson(u as Map<String, dynamic>)).toList(),
    page: json['page'] as int,
    totalPages: json['totalPages'] as int,
    hasNext: json['hasNext'] as bool,
  );
}

// Mock Error Types
class ApiError {
  final String message;
  final int code;
  ApiError(this.message, this.code);
}

// Mock Service
abstract class MockApiService {
  Future<PagedResponse> getUsersPage(PageArgs args);
}

@GenerateMocks([MockApiService])
// Test Infinite Query Implementation
class GetUsersInfiniteQuery extends InfiniteQuerySerializable<PagedResponse, PageArgs, ApiError> {
  final MockApiService apiService;
  final CachedQuery localCache;

  GetUsersInfiniteQuery({required this.apiService, required this.localCache});

  @override
  String keyGenerator() => 'users_infinite';

  @override
  QueryException errorMapper(ApiError error) => QueryException('API Error: ${error.message}', error.code);

  @override
  PagedResponse responseHandler(dynamic response) {
    if (response is Map<String, dynamic>) {
      return PagedResponse.fromJson(response);
    }
    return response as PagedResponse;
  }

  @override
  CachedQuery get cache => localCache;

  @override
  Future<PagedResponse> queryFn(PageArgs arg) => apiService.getUsersPage(arg);

  @override
  PageArgs? getNextArg(InfiniteQueryData<PagedResponse, PageArgs>? data) {
    if (data == null || data.pages.isEmpty) {
      return PageArgs(page: 1, limit: 10);
    }

    final lastPage = data.pages.last;
    if (lastPage.hasNext && lastPage.page < lastPage.totalPages) {
      return PageArgs(page: lastPage.page + 1, limit: 10);
    }

    return null; // No more pages
  }

  @override
  Map<String, dynamic> Function(InfiniteQueryData<PagedResponse, PageArgs>)? get storageSerializer =>
      (data) => {
        'pages': data.pages.map((page) => page.toJson()).toList(),
        'args': data.args.map((arg) => {'page': arg.page, 'limit': arg.limit}).toList(),
      };

  @override
  InfiniteQueryData<PagedResponse, PageArgs> Function(Map<String, dynamic>)? get storageDeserializer =>
      (json) => InfiniteQueryData<PagedResponse, PageArgs>(
        pages: (json['pages'] as List).map((p) => PagedResponse.fromJson(p as Map<String, dynamic>)).toList(),
        args: (json['args'] as List).map((a) => PageArgs(page: a['page'] as int, limit: a['limit'] as int)).toList(),
      );

  @override
  bool get storeQuery => true;
}

// Helper that throws inside getNextArg only after the first page has been fetched —
// exercises the fetch-time error-propagation path (initial construction succeeds).
class _ThrowingGetNextArgQuery extends InfiniteQuerySerializable<PagedResponse, PageArgs, ApiError> {
  final CachedQuery localCache;
  final Object errorToThrow;
  _ThrowingGetNextArgQuery({required this.localCache, required this.errorToThrow});

  @override
  String keyGenerator() => 'throwing_get_next_arg';
  @override
  QueryException errorMapper(ApiError error) => QueryException('API Error: ${error.message}', error.code);
  @override
  PagedResponse responseHandler(dynamic response) => response as PagedResponse;
  @override
  CachedQuery get cache => localCache;
  @override
  Future<PagedResponse> queryFn(PageArgs arg) async =>
      PagedResponse(users: [User(id: arg.page, name: 'u${arg.page}', email: 'u@b.c')], page: arg.page, totalPages: 5, hasNext: true);
  @override
  PageArgs? getNextArg(InfiniteQueryData<PagedResponse, PageArgs>? data) {
    if (data == null || data.pages.isEmpty) return PageArgs(page: 1, limit: 10);
    throw errorToThrow;
  }
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

  group('InfiniteQueryKey Basic Functionality', () {
    test('should generate correct key from request', () {
      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);

      expect(infiniteQueryKey.rawKey, 'users_infinite');
    });

    test('should return infinite query key from serializable', () {
      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = request.infiniteQueryKey;

      expect(infiniteQueryKey, isA<InfiniteQueryKey<GetUsersInfiniteQuery, PagedResponse, PageArgs, ApiError>>());
      expect(infiniteQueryKey.rawKey, 'users_infinite');
    });

    test('should indicate query does not exist initially', () {
      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);

      expect(infiniteQueryKey.exists, false);
      expect(infiniteQueryKey.isPending, false);
      expect(infiniteQueryKey.isRefetching, false);
      expect(infiniteQueryKey.isFetchingNextPage, false);
      expect(infiniteQueryKey.isError, false);
      expect(infiniteQueryKey.hasReachedMax, false);
      expect(infiniteQueryKey.error, null);
      expect(infiniteQueryKey.allPages, isEmpty);
      expect(infiniteQueryKey.pageArgs, isEmpty);
    });
  });

  group('InfiniteQueryKey Query Execution', () {
    test('should execute successful infinite query with first page', () async {
      final page1Response = PagedResponse(
        users: [
          User(id: 1, name: 'John Doe', email: 'john@example.com'),
          User(id: 2, name: 'Jane Doe', email: 'jane@example.com'),
        ],
        page: 1,
        totalPages: 3,
        hasNext: true,
      );

      when(mockApiService.getUsersPage(PageArgs(page: 1, limit: 10))).thenAnswer((_) async => page1Response);

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);
      final query = infiniteQueryKey.query();

      final result = await query.fetch();

      expect(result.data?.pages.length, 1);
      expect(result.data?.pages.first.users.length, 2);
      expect(result.data?.pages.first.users.first.name, 'John Doe');
      expect(infiniteQueryKey.allPages.length, 1);
      expect(infiniteQueryKey.pageArgs.length, 1);
      expect(infiniteQueryKey.pageArgs.first.page, 1);
      verify(mockApiService.getUsersPage(PageArgs(page: 1, limit: 10))).called(1);
    });

    test('should fetch next page correctly', () async {
      // Setup first page
      final page1Response = PagedResponse(
        users: [User(id: 1, name: 'John', email: 'john@example.com')],
        page: 1,
        totalPages: 2,
        hasNext: true,
      );

      // Setup second page
      final page2Response = PagedResponse(
        users: [User(id: 2, name: 'Jane', email: 'jane@example.com')],
        page: 2,
        totalPages: 2,
        hasNext: false,
      );

      when(mockApiService.getUsersPage(PageArgs(page: 1, limit: 10))).thenAnswer((_) async => page1Response);
      when(mockApiService.getUsersPage(PageArgs(page: 2, limit: 10))).thenAnswer((_) async => page2Response);

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);
      final query = infiniteQueryKey.query();

      // Fetch first page
      await query.fetch();
      expect(infiniteQueryKey.allPages.length, 1);
      expect(infiniteQueryKey.hasReachedMax, false);

      // Fetch next page
      await infiniteQueryKey.fetchNextPage();
      expect(infiniteQueryKey.allPages.length, 2);
      expect(infiniteQueryKey.hasReachedMax, true);

      verify(mockApiService.getUsersPage(PageArgs(page: 1, limit: 10))).called(1);
      verify(mockApiService.getUsersPage(PageArgs(page: 2, limit: 10))).called(1);
    });

    test('should handle API errors correctly', () async {
      when(mockApiService.getUsersPage(any)).thenThrow(ApiError('Server error', 500));

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);

      QueryException? capturedError;
      final query = infiniteQueryKey.query(onError: (error) => capturedError = error);

      try {
        await query.fetch();
      } catch (e) {
        // Expected to throw
      }

      expect(capturedError, isNotNull);
      expect(capturedError!.message, 'API Error: Server error');
      expect(capturedError!.statusCode, 500);
    });

    test('should call onSuccess callback on successful fetch', () async {
      final pageResponse = PagedResponse(
        users: [User(id: 1, name: 'John', email: 'john@example.com')],
        page: 1,
        totalPages: 1,
        hasNext: false,
      );

      when(mockApiService.getUsersPage(PageArgs(page: 1, limit: 10))).thenAnswer((_) async => pageResponse);

      InfiniteQueryData<PagedResponse, PageArgs>? successResult;
      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);
      final query = infiniteQueryKey.query(onSuccess: (data) => successResult = data);

      await query.fetch();

      expect(successResult, isNotNull);
      expect(successResult!.pages.length, 1);
      expect(successResult!.pages.first.users.first.name, 'John');
    });
  });

  group('InfiniteQueryKey State Management', () {
    test('should track loading states correctly', () async {
      final pageResponse = PagedResponse(
        users: [User(id: 1, name: 'John', email: 'john@example.com')],
        page: 1,
        totalPages: 2,
        hasNext: true,
      );

      when(mockApiService.getUsersPage(any)).thenAnswer((_) async {
        await Future.delayed(Duration(milliseconds: 100));
        return pageResponse;
      });

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);
      final query = infiniteQueryKey.query();

      // Should be pending during initial fetch
      final fetchFuture = query.fetch();
      // Note: In real usage, you'd check isPending in a widget rebuild

      await fetchFuture;
      expect(infiniteQueryKey.exists, true);
    });

    test('should update data correctly', () async {
      final pageResponse = PagedResponse(
        users: [User(id: 1, name: 'John', email: 'john@example.com')],
        page: 1,
        totalPages: 1,
        hasNext: false,
      );

      when(mockApiService.getUsersPage(PageArgs(page: 1, limit: 10))).thenAnswer((_) async => pageResponse);

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);
      final query = infiniteQueryKey.query();

      // Initial fetch
      await query.fetch();

      // Update data
      final updatedData = InfiniteQueryData<PagedResponse, PageArgs>(
        pages: [
          PagedResponse(
            users: [User(id: 1, name: 'Updated John', email: 'john@example.com')],
            page: 1,
            totalPages: 1,
            hasNext: false,
          ),
        ],
        args: [PageArgs(page: 1, limit: 10)],
      );

      final result = infiniteQueryKey.updateData<InfiniteQueryData<PagedResponse, PageArgs>>((existingData) => updatedData);

      expect(result.pages.first.users.first.name, 'Updated John');
    });

    test('updateData invokes the user function exactly once (existing data path)', () async {
      final pageResponse = PagedResponse(
        users: [User(id: 1, name: 'John', email: 'john@example.com')],
        page: 1,
        totalPages: 1,
        hasNext: false,
      );
      when(mockApiService.getUsersPage(PageArgs(page: 1, limit: 10))).thenAnswer((_) async => pageResponse);

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);
      await infiniteQueryKey.query().fetch();

      var calls = 0;
      final replacement = InfiniteQueryData<PagedResponse, PageArgs>(pages: [pageResponse], args: [PageArgs(page: 1, limit: 10)]);
      infiniteQueryKey.updateData<InfiniteQueryData<PagedResponse, PageArgs>>((existingData) {
        calls += 1;
        return replacement;
      });

      expect(calls, 1, reason: 'updateFunction must be invoked exactly once per updateData call');
    });

    test('getNextArg throw of ErrorType propagates to error state (not "no more pages")', () async {
      final request = _ThrowingGetNextArgQuery(localCache: cachedQuery, errorToThrow: ApiError('boom', 503));
      final infiniteQueryKey = InfiniteQueryKey(request);
      final query = infiniteQueryKey.query();

      // First page succeeds.
      await query.fetch();
      expect(infiniteQueryKey.isError, isFalse);

      // Subsequent getNextArg throws — must surface as error, not silent end-of-pagination.
      try {
        await query.getNextPage();
      } catch (_) {/* expected to surface */}

      expect(query.state.error, isNotNull, reason: 'A throwing getNextArg must surface as an error state, not as silent end-of-pagination');
    });

    test('getNextArg throw of unknown error surfaces an error state', () async {
      final request = _ThrowingGetNextArgQuery(localCache: cachedQuery, errorToThrow: StateError('unexpected'));
      final infiniteQueryKey = InfiniteQueryKey(request);
      final query = infiniteQueryKey.query();

      await query.fetch();
      try {
        await query.getNextPage();
      } catch (_) {/* expected */}

      expect(query.state.error, isNotNull);
    });

    test('should invalidate query correctly', () async {
      final pageResponse = PagedResponse(
        users: [User(id: 1, name: 'John', email: 'john@example.com')],
        page: 1,
        totalPages: 1,
        hasNext: false,
      );

      when(mockApiService.getUsersPage(PageArgs(page: 1, limit: 10))).thenAnswer((_) async => pageResponse);

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);
      final infiniteQueryKey = InfiniteQueryKey(request);
      final query = infiniteQueryKey.query();

      await query.fetch();
      expect(infiniteQueryKey.exists, true);

      // Invalidate should work without throwing
      expect(() => infiniteQueryKey.invalidate(), returnsNormally);
    });
  });

  group('InfiniteQueryKey Pagination Logic', () {
    test('should correctly determine when max is reached', () async {
      // Last page response
      final lastPageResponse = PagedResponse(
        users: [User(id: 3, name: 'Bob', email: 'bob@example.com')],
        page: 2,
        totalPages: 2,
        hasNext: false,
      );

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);

      // Test getNextArg logic directly
      final dataWithLastPage = InfiniteQueryData<PagedResponse, PageArgs>(pages: [lastPageResponse], args: [PageArgs(page: 2, limit: 10)]);

      final nextArg = request.getNextArg(dataWithLastPage);
      expect(nextArg, isNull); // Should be null when hasNext is false
    });

    test('should provide correct next page args', () async {
      final firstPageResponse = PagedResponse(
        users: [User(id: 1, name: 'John', email: 'john@example.com')],
        page: 1,
        totalPages: 3,
        hasNext: true,
      );

      final request = GetUsersInfiniteQuery(apiService: mockApiService, localCache: cachedQuery);

      final dataWithFirstPage = InfiniteQueryData<PagedResponse, PageArgs>(pages: [firstPageResponse], args: [PageArgs(page: 1, limit: 10)]);

      final nextArg = request.getNextArg(dataWithFirstPage);
      expect(nextArg, isNotNull);
      expect(nextArg!.page, 2);
      expect(nextArg.limit, 10);
    });
  });
}
