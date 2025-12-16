import 'user.dart';

class PagedResponse {
  final List<User> users;
  final String? nextCursor;
  final bool hasNext;
  final int totalCount;

  PagedResponse({required this.users, this.nextCursor, required this.hasNext, required this.totalCount});

  factory PagedResponse.fromJson(Map<String, dynamic> json) {
    return PagedResponse(
      users: (json['users'] as List<dynamic>).map((item) => User.fromJson(item as Map<String, dynamic>)).toList(),
      nextCursor: json['nextCursor'] as String?,
      hasNext: json['hasNext'] as bool,
      totalCount: json['totalCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'users': users.map((user) => user.toJson()).toList(),
      if (nextCursor != null) 'nextCursor': nextCursor,
      'hasNext': hasNext,
      'totalCount': totalCount,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PagedResponse &&
        other.users.length == users.length &&
        other.nextCursor == nextCursor &&
        other.hasNext == hasNext &&
        other.totalCount == totalCount;
  }

  @override
  int get hashCode => users.hashCode ^ nextCursor.hashCode ^ hasNext.hashCode ^ totalCount.hashCode;
}
