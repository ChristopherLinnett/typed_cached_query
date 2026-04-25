import 'dart:convert';

import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/serializable.dart';
import 'user.dart';
import 'validation_error.dart';
import 'mock_api_service.dart';

class CreateUserRequest extends MutationSerializable<CreateUserRequest, User, ValidationError> {
  final String name;
  final String email;
  final MockApiService apiService;
  final MutationCache? _cache;

  CreateUserRequest({required this.name, required this.email, required this.apiService, MutationCache? cache}) : _cache = cache;

  @override
  MutationCache? get cache => _cache;

  @override
  String get keyGenerator => 'create_user_${jsonEncode(toJson())}';

  @override
  OnErrorResults<CreateUserRequest, User?> errorMapper(CreateUserRequest request, ValidationError error, User? fallback) {
    final errorMessage = error.fieldErrors.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('; ');
    return OnErrorResults(request: request, error: MutationException('Validation failed - $errorMessage', 400), fallback: fallback);
  }

  @override
  User responseHandler(dynamic response) => response is User ? response : User.fromJson(response as Map<String, dynamic>);

  @override
  Future<User> mutationFn() async {
    return apiService.createUser(this);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'name': name, 'email': email};
  }

  factory CreateUserRequest.fromJson(Map<String, dynamic> json) {
    // This won't have apiService when deserializing, but that's okay for data transfer
    throw UnimplementedError('CreateUserRequest.fromJson should not be used for mutation requests');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreateUserRequest && other.name == name && other.email == email;
  }

  @override
  int get hashCode => name.hashCode ^ email.hashCode;
}
