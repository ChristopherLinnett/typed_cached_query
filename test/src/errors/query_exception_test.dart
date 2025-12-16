import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/errors/query_exception.dart';

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
