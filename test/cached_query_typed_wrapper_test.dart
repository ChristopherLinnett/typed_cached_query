import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import 'package:typed_cached_query/src/errors/query_exception.dart';

// Mock API Error Types
class ApiError {
  final String message;
  final int code;
  ApiError(this.message, this.code);
}

class NetworkError {
  final String reason;
  NetworkError(this.reason);
}

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

class CreateUserRequest {
  final String name;
  final String email;

  CreateUserRequest({required this.name, required this.email});

  Map<String, dynamic> toJson() => {'name': name, 'email': email};
}

// Mock Services
abstract class MockApiService {
  Future<User> getUser(int id);
  Future<User> createUser(CreateUserRequest request);
  Future<List<User>> getUsers();
}

@GenerateMocks([MockApiService])
void main() {
  group('QueryException Tests', () {
    test('should create QueryException with message and status code', () {
      final exception = QueryException('Not found', 404);

      expect(exception.message, 'Not found');
      expect(exception.statusCode, 404);
      expect(exception.toString(), 'QueryException: Not found (Status Code: 404)');
    });

    test('should check equality correctly', () {
      final exception1 = QueryException('Error', 500);
      final exception2 = QueryException('Error', 500);
      final exception3 = QueryException('Different', 500);

      expect(exception1 == exception2, true);
      expect(exception1 == exception3, false);
      expect(exception1.hashCode == exception2.hashCode, true);
    });
  });

  group('MutationException Tests', () {
    test('should create MutationException with message and status code', () {
      final exception = MutationException('Validation failed', 400);

      expect(exception.message, 'Validation failed');
      expect(exception.statusCode, 400);
      expect(exception.toString(), 'MutationException: Validation failed (Status Code: 400)');
    });

    test('should check equality correctly', () {
      final exception1 = MutationException('Error', 500);
      final exception2 = MutationException('Error', 500);
      final exception3 = MutationException('Different', 400);

      expect(exception1 == exception2, true);
      expect(exception1 == exception3, false);
      expect(exception1.hashCode == exception2.hashCode, true);
    });
  });
}
