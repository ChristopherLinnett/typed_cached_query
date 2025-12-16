import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/typed_cached_query.dart';
import 'user.dart';
import 'network_error.dart';
import 'mock_api_service.dart';
import 'create_user_request.dart';

// Helper class for retry testing
class RetryableCreateUserRequest extends MutationSerializable<RetryableCreateUserRequest, User, NetworkError> {
  final String name;
  final String email;
  final MockApiService apiService;
  final MutationCache? _cache;

  RetryableCreateUserRequest({required this.name, required this.email, required this.apiService, MutationCache? cache}) : _cache = cache;

  @override
  MutationCache? get cache => _cache;

  @override
  String keyGenerator() => 'retryable_create_$name';

  @override
  OnErrorResults<RetryableCreateUserRequest, User?> errorMapper(RetryableCreateUserRequest request, NetworkError error, User? fallback) {
    return OnErrorResults(request: request, error: MutationException('Network error: ${error.reason}', 503), fallback: fallback);
  }

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> mutationFn() => apiService.createUser(CreateUserRequest(name: name, email: email, apiService: apiService));

  @override
  Map<String, dynamic> toJson() => {'name': name, 'email': email};
}
