# Typed Cached Query

[![CI](https://github.com/ChristopherLinnett/typed_cached_query/actions/workflows/ci.yml/badge.svg)](https://github.com/ChristopherLinnett/typed_cached_query/actions/workflows/ci.yml)

A type-safe wrapper around [cached_query_flutter](https://pub.dev/packages/cached_query_flutter) that provides a clean, strongly-typed API for managing queries and mutations in Flutter applications.

This package abstracts away the complexity of cached_query_flutter while providing better type safety, reduced boilerplate, and a more intuitive API for developers.

## Features

- **Type-safe queries and mutations**: Define your API calls with full type safety
- **Automatic caching**: Built-in intelligent caching with configurable policies  
- **Error handling**: Strongly-typed error handling with custom exception mapping
- **Clean API**: Simple, intuitive API that hides cached_query_flutter complexity
- **Testing support**: Easy-to-mock interfaces for unit testing
- **Flutter integration**: Seamless integration with Flutter lifecycle and connectivity

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  typed_cached_query: ^0.0.1
```

### Configuration

Initialize the library in your app's main function:

```dart
import 'package:typed_cached_query/typed_cached_query.dart';

void main() {
  // Configure the library (call this once at app startup)
  TypedCachedQuery.configureFlutter(
    config: GlobalQueryConfig(
      staleDuration: Duration(minutes: 5),
      cacheDuration: Duration(hours: 1),
    ),
  );
  
  runApp(MyApp());
}
```

## Usage

### 1. Define Your Data Models

```dart
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
}
```

### 2. Create Query Classes

```dart
class GetUserRequest extends QuerySerializable<User, ApiError> {
  final int userId;
  final ApiService apiService;

  GetUserRequest({required this.userId, required this.apiService});

  @override
  String get keyGenerator => 'user_$userId';

  @override
  QueryException errorMapper(ApiError error) => 
      QueryException('Failed to get user: ${error.message}', error.statusCode);

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> queryFn() => apiService.getUser(userId);

  @override
  Map<String, dynamic> Function(User)? get storageSerializer => (user) => user.toJson();

  @override
  User Function(Map<String, dynamic>)? get storageDeserializer => User.fromJson;

  @override
  bool get storeQuery => true; // Enable persistent storage
}
```

### 3. Create Mutation Classes

```dart
class UpdateUserRequest extends MutationSerializable<UpdateUserRequest, User, ApiError> {
  final String name;
  final String email;
  final ApiService apiService;

  UpdateUserRequest({required this.name, required this.email, required this.apiService});

  @override
  String get keyGenerator => 'update_user';

  @override
  OnErrorResults<UpdateUserRequest, User?> errorMapper(
      UpdateUserRequest request, ApiError error, User? fallback) {
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
```

### 4. Use in Your Widgets

```dart
class UserProfileWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final getUserQuery = GetUserRequest(userId: 1, apiService: ApiService());
    final queryKey = getUserQuery.queryKey;

    return FutureBuilder(
      future: queryKey.query().fetch(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text('User: ${snapshot.data!.data!.name}');
        }
        return CircularProgressIndicator();
      },
    );
  }
}
```

### 5. Handle Mutations

```dart
void updateUser() async {
  final mutation = UpdateUserRequest(
    name: 'Jane Doe',
    email: 'jane@example.com', 
    apiService: ApiService(),
  );

  final mutationKey = mutation.mutationKey;
  final result = await mutationKey.mutate(
    onSuccess: (user, request) => print('User updated: ${user.name}'),
    onError: (request, error, fallback) => print('Error: ${error.message}'),
  );
}
```

## Key Concepts

- **QuerySerializable**: Base class for all query operations (GET requests)
- **MutationSerializable**: Base class for all mutation operations (POST/PUT/DELETE requests)  
- **QueryKey**: Provides access to query state and operations
- **MutationKey**: Provides access to mutation state and operations
- **Type Safety**: All operations are fully typed with your custom data models and error types

## Testing

The library provides isolated cache instances for testing:

```dart
void main() {
  test('should handle user query', () async {
    final isolatedCache = TypedCachedQuery.createNewInstance();
    final query = GetUserRequest(
      userId: 1, 
      apiService: MockApiService(),
    );
    
    // Test your query logic...
  });
}
```

## Additional Information

This package is a wrapper around [cached_query_flutter](https://pub.dev/packages/cached_query_flutter) and provides a more developer-friendly API while maintaining all the powerful caching and state management features of the underlying library.

For more examples, see the `/example` folder in the repository.

## Development

Local setup for contributors:

```bash
# Resolve dependencies (use dart pub get rather than flutter pub get)
dart pub get

# (Re)generate mockito mocks if you change @GenerateMocks declarations
dart run build_runner build --delete-conflicting-outputs

# Run static analysis on lib/
dart analyze --fatal-infos lib/

# Run the full test suite
flutter test
```

CI runs the same `dart pub get` → `dart analyze --fatal-infos lib/` → `flutter test` pipeline on every push and pull request.
