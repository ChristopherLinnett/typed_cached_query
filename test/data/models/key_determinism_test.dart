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
      expect(a1.keyGenerator, a2.keyGenerator, reason: 'two requests with the same input must hash to the same key');
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
