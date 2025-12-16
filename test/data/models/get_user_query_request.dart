import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/serializable.dart';
import 'user.dart';
import 'api_error.dart';
import 'mock_api_service.dart';

class GetUserQueryRequest extends QuerySerializable<User, ApiError> {
  final int userId;
  final MockApiService apiService;
  final bool enableCache;
  final CachedQuery? _cache;

  GetUserQueryRequest({required this.userId, required this.apiService, this.enableCache = true, CachedQuery? cache}) : _cache = cache;

  @override
  CachedQuery? get cache => _cache;

  @override
  Map<String, dynamic> toJson() => {'userId': userId, 'enableCache': enableCache};

  @override
  QueryException errorMapper(ApiError error) => QueryException('Failed to get user: ${error.message}', error.statusCode);

  @override
  User responseHandler(dynamic response) => response is User ? response : User.fromJson(response as Map<String, dynamic>);

  @override
  Future<User> queryFn() => apiService.getUser(userId);

  @override
  Map<String, dynamic> Function(User)? get storageSerializer => enableCache ? (user) => user.toJson() : null;

  @override
  User Function(Map<String, dynamic>)? get storageDeserializer => enableCache ? User.fromJson : null;

  @override
  bool get storeQuery => enableCache;
}
