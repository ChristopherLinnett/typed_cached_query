// This is example code that demonstrates listener callbacks via `print`. Suppress the
// `avoid_print` lint here so the example reads clearly without requiring a logger.
// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:typed_cached_query/typed_cached_query.dart';

void main() {
  // Initialize the library once in your app
  TypedCachedQuery.configureFlutter(
    config: GlobalQueryConfig(staleDuration: Duration(minutes: 5), cacheDuration: Duration(hours: 1)),
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Typed Cached Query Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (context) => UserProfileScreen())),
              child: Text('Single User Profile'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (context) => UsersListScreen())),
              child: Text('Paginated Users List'),
            ),
          ],
        ),
      ),
    );
  }
}

// Example data model
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(id: json['id'] as int, name: json['name'] as String, email: json['email'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}

// Example API service
class ApiService {
  Future<User> getUser(int id) async {
    // Simulate API call
    await Future<void>.delayed(Duration(seconds: 1));
    return User(id: id, name: 'John Doe', email: 'john@example.com');
  }

  Future<User> updateUser(String name, String email) async {
    // Simulate API call
    await Future<void>.delayed(Duration(seconds: 1));
    return User(id: 1, name: name, email: email);
  }

  Future<List<User>> getUsersPage(int page) async {
    // Simulate paginated API call
    await Future<void>.delayed(Duration(seconds: 1));

    // Return 5 users per page, stop after page 3
    if (page > 3) return [];

    return List.generate(5, (index) {
      final id = (page - 1) * 5 + index + 1;
      return User(id: id, name: 'User $id', email: 'user$id@example.com');
    });
  }
}

// Example error types
class ApiError {
  final String message;
  final int statusCode;

  ApiError(this.message, this.statusCode);
}

// Example query implementation
class GetUserRequest extends QuerySerializable<User, ApiError> {
  final int userId;
  final ApiService apiService;

  GetUserRequest({required this.userId, required this.apiService});

  @override
  String get keyGenerator => 'user_$userId';

  @override
  QueryException errorMapper(ApiError error) => QueryException('Failed to get user: ${error.message}', error.statusCode);

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> queryFn() => apiService.getUser(userId);

  @override
  Map<String, dynamic> Function(User)? get storageSerializer =>
      (user) => user.toJson();

  @override
  User Function(Map<String, dynamic>)? get storageDeserializer => User.fromJson;

  @override
  bool get storeQuery => true;
  
  @override
  Map<String, dynamic> toJson() => {"userId": userId};
}

// Example mutation implementation
class UpdateUserRequest extends MutationSerializable<UpdateUserRequest, User, ApiError> {
  final String name;
  final String email;
  final ApiService apiService;

  UpdateUserRequest({required this.name, required this.email, required this.apiService});

  @override
  String get keyGenerator => 'update_user';

  @override
  OnErrorResults<UpdateUserRequest, User?> errorMapper(UpdateUserRequest request, ApiError error, User? fallback) {
    return OnErrorResults(
      request: request,
      error: MutationException('Failed to update user: ${error.message}', error.statusCode),
      fallback: fallback,
    );
  }

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> mutationFn() => apiService.updateUser(name, email);
}

// Example infinite query implementation
class GetUsersPageRequest extends InfiniteQuerySerializable<List<User>, int, ApiError> {
  final ApiService apiService;

  GetUsersPageRequest({required this.apiService});

  @override
  String get keyGenerator => 'users_page';

  @override
  QueryException errorMapper(ApiError error) => QueryException('Failed to get users: ${error.message}', error.statusCode);

  @override
  List<User> responseHandler(dynamic response) => (response as List).map((json) => User.fromJson(json as Map<String, dynamic>)).toList();

  @override
  Future<List<User>> queryFn(int page) => apiService.getUsersPage(page);

  @override
  int? getNextArg(InfiniteQueryData<List<User>, int>? currentData) {
    if (currentData == null) return 1; // First page

    // Get the last page of data
    final lastPage = currentData.pages.lastOrNull;

    // If the last page is empty or null, we've reached the end
    if (lastPage == null || lastPage.isEmpty) {
      return null;
    }

    // Return next page number
    final lastArg = currentData.args.lastOrNull ?? 0;
    return lastArg + 1;
  }

  @override
  Map<String, dynamic> Function(InfiniteQueryData<List<User>, int>)? get storageSerializer =>
      (data) => {'pages': data.pages.map((users) => users.map((u) => u.toJson()).toList()).toList(), 'args': data.args};

  @override
  InfiniteQueryData<List<User>, int> Function(Map<String, dynamic>)? get storageDeserializer =>
      (json) => InfiniteQueryData<List<User>, int>(
        pages: (json['pages'] as List).map((page) => (page as List).map((u) => User.fromJson(u as Map<String, dynamic>)).toList()).toList(),
        args: (json['args'] as List).cast<int>(),
      );

  @override
  bool get storeQuery => true;
}

class UserProfileScreen extends StatelessWidget {
  final ApiService _apiService = ApiService();

  UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Create query and mutation instances
    final getUserQuery = GetUserRequest(userId: 1, apiService: _apiService);
    final updateUserMutation = UpdateUserRequest(name: 'Jane Doe', email: 'jane@example.com', apiService: _apiService);

    return Scaffold(
      appBar: AppBar(title: Text('User Profile')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Typed Query Builder Example
            Expanded(
              child: TypedQueryBuilder<User>(
                query: getUserQuery.query(),
                builder: (context, state) {
                  if (state.isLoading) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (state.isError) {
                    return Center(
                      child: Text('Error: ${state.error}', style: TextStyle(color: Colors.red)),
                    );
                  }

                  if (state.data != null) {
                    final user = state.data!;
                    return Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('User Profile', style: Theme.of(context).textTheme.headlineMedium),
                              SizedBox(height: 16),
                              Text('Name: ${user.name}'),
                              Text('Email: ${user.email}'),
                              Text('ID: ${user.id}'),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Center(child: Text('No data available'));
                },
              ),
            ),

            SizedBox(height: 16),

            // Typed Mutation Builder Example
            TypedMutationBuilder<User, UpdateUserRequest>(
              mutation: updateUserMutation.definition(
                onSuccess: (user, request) =>
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully updated user: ${user.name}'))),
                onError: (request, error, fallback) =>
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${error.message}'), backgroundColor: Colors.red)),
              ),
              builder: (context, state, mutate) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.isLoading ? null : () => mutate(updateUserMutation),
                    child: state.isLoading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Updating...'),
                            ],
                          )
                        : Text('Update User Profile'),
                  ),
                );
              },
            ),

            SizedBox(height: 16),

            // Typed Query Listener Example (listens for changes without UI)
            TypedQueryListener<User>(
              query: getUserQuery.query(),
              onChange: (context, state) => print('User query state changed'),
              onSuccess: (context, state) => print('User loaded: ${state.data?.name}'),
              onError: (context, state) => print('User query error: ${state.error}'),
              onLoading: (context, state) => print('User query loading...'),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('This widget listens for user query changes (check console)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UsersListScreen extends StatelessWidget {
  final ApiService _apiService = ApiService();

  UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final getUsersPage = GetUsersPageRequest(apiService: _apiService);
    final refreshMutation = UpdateUserRequest(name: 'Refreshed User', email: 'refresh@example.com', apiService: _apiService);

    return Scaffold(
      appBar: AppBar(title: Text('Users List'), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: TypedMutationListener<User, UpdateUserRequest>(
        mutation: refreshMutation.definition(),
        onSuccess: (context, state) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh completed!'))),
        onError: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh failed'), backgroundColor: Colors.red)),
        child: TypedInfiniteQueryBuilder<List<User>, int>(
          query: getUsersPage.infiniteQuery(),
          builder: (context, state, fetchNextPage, hasReachedMax) {
            if (state.isLoading && (state.data?.pages.isEmpty ?? true)) {
              return Center(child: CircularProgressIndicator());
            }

            if (state.isError && (state.data?.pages.isEmpty ?? true)) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text('Error: ${state.error}', style: TextStyle(color: Colors.red)),
                    SizedBox(height: 16),
                    ElevatedButton(onPressed: () => fetchNextPage(), child: Text('Retry')),
                  ],
                ),
              );
            }

            final allUsers = state.data?.pages.expand<User>((List<User> page) => page).toList() ?? <User>[];

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: allUsers.length + (hasReachedMax ? 0 : 1),
                    itemBuilder: (context, index) {
                      if (index >= allUsers.length) {
                        // Load more button/indicator
                        return Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: state.isLoading
                                ? Column(children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Loading more users...')])
                                : ElevatedButton(onPressed: () => fetchNextPage(), child: Text('Load More Users')),
                          ),
                        );
                      }

                      final user = allUsers[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.blue, child: Text('${user.id}')),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          trailing: Icon(Icons.person),
                        ),
                      );
                    },
                  ),
                ),
                if (hasReachedMax)
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.grey[200],
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        'No more users to load • ${allUsers.length} total',
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
