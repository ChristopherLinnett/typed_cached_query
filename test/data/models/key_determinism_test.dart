import 'package:flutter_test/flutter_test.dart';

import 'create_user_request.dart';
import 'update_user_request.dart';
import 'retryable_create_user_request.dart';
import 'mock_api_service.dart';

class _StubApiService implements MockApiService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Test fixture keyGenerator determinism', () {
    test('CreateUserRequest.keyGenerator is stable per instance and per equal input', () {
      final api = _StubApiService();
      final a1 = CreateUserRequest(name: 'Alice', email: 'a@b.c', apiService: api);
      final a2 = CreateUserRequest(name: 'Alice', email: 'a@b.c', apiService: api);

      expect(a1.keyGenerator, a1.keyGenerator, reason: 'repeated reads must return the same key');
      expect(a1.keyGenerator, a2.keyGenerator, reason: 'two requests with the same input must produce the same key');
    });

    test('CreateUserRequest.keyGenerator does not collide when fields contain underscores', () {
      // Underscore-concatenated keys (the prior shape) collided when either field contained '_':
      // (name: 'a_b', email: 'c') vs (name: 'a', email: 'b_c'). Using JSON encoding avoids this.
      final api = _StubApiService();
      final a = CreateUserRequest(name: 'a_b', email: 'c', apiService: api);
      final b = CreateUserRequest(name: 'a', email: 'b_c', apiService: api);
      expect(a.keyGenerator, isNot(b.keyGenerator));
    });

    test('UpdateUserRequest.keyGenerator is stable per instance', () {
      final api = _StubApiService();
      final r = UpdateUserRequest(id: 1, name: 'A', email: 'a@b.c', apiService: api);
      expect(r.keyGenerator, r.keyGenerator);
    });

    test('RetryableCreateUserRequest.keyGenerator is stable per instance', () {
      final api = _StubApiService();
      final r = RetryableCreateUserRequest(name: 'A', email: 'a@b.c', apiService: api);
      expect(r.keyGenerator, r.keyGenerator);
    });
  });
}
