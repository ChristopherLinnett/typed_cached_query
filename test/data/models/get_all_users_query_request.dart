import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/serializable.dart';
import 'user.dart';
import 'network_error.dart';
import 'mock_api_service.dart';

class GetAllUsersQueryRequest extends QuerySerializable<List<User>, NetworkError> {
  final MockApiService apiService;
  final CachedQuery? _cache;

  GetAllUsersQueryRequest({required this.apiService, CachedQuery? cache}) : _cache = cache;

  @override
  CachedQuery? get cache => _cache;

  @override
  Map<String, dynamic> toJson() => {};

  @override
  QueryException errorMapper(NetworkError error) => QueryException('Failed to get users: ${error.reason}', 503);

  @override
  List<User> responseHandler(dynamic response) {
    if (response is List<User>) return response;
    if (response is List) {
      return response.map((item) => item is User ? item : User.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw ArgumentError('Invalid response type for users list');
  }

  @override
  Future<List<User>> queryFn() => apiService.getUsers();

  @override
  Map<String, dynamic> Function(List<User>)? get storageSerializer => null;

  @override
  List<User> Function(Map<String, dynamic>)? get storageDeserializer => null;

  @override
  bool get storeQuery => false;
}
