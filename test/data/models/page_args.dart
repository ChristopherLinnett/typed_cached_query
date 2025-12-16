class PageArgs {
  final int limit;
  final String? cursor;
  final Map<String, dynamic> filters;

  PageArgs({required this.limit, this.cursor, this.filters = const {}});

  factory PageArgs.fromJson(Map<String, dynamic> json) {
    return PageArgs(limit: json['limit'] as int, cursor: json['cursor'] as String?, filters: (json['filters'] as Map<String, dynamic>?) ?? const {});
  }

  Map<String, dynamic> toJson() {
    return {'limit': limit, if (cursor != null) 'cursor': cursor, if (filters.isNotEmpty) 'filters': filters};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PageArgs && other.limit == limit && other.cursor == cursor;
  }

  @override
  int get hashCode => limit.hashCode ^ cursor.hashCode;
}
