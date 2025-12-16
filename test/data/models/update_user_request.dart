import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/serializable.dart';
import 'user.dart';
import 'api_error.dart';
import 'mock_api_service.dart';

class UpdateUserRequest extends MutationSerializable<UpdateUserRequest, User, ApiError> {
  final int id;
  final String name;
  final String? email;
  final MockApiService apiService;
  final MutationCache? _cache;

  UpdateUserRequest({required this.id, required this.name, this.email, required this.apiService, MutationCache? cache}) : _cache = cache;

  @override
  MutationCache? get cache => _cache;

  @override
  String keyGenerator() => 'update_user_$id';

  @override
  OnErrorResults<UpdateUserRequest, User?> errorMapper(UpdateUserRequest request, ApiError error, User? fallback) {
    return OnErrorResults(request: request, error: MutationException('Update failed: ${error.message}', error.statusCode), fallback: fallback);
  }

  @override
  User responseHandler(dynamic response) => response as User;

  @override
  Future<User> mutationFn() => apiService.updateUser(this);

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, if (email != null) 'email': email};
  }

  factory UpdateUserRequest.fromJson(Map<String, dynamic> json) {
    throw UnimplementedError('UpdateUserRequest.fromJson should not be used for mutation requests');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateUserRequest && other.id == id && other.name == name && other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ email.hashCode;
}
