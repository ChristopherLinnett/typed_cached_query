import 'package:flutter_test/flutter_test.dart';

import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

// Two declarations to set up a CRTP misdeclaration: _Self correctly self-types its F-bounded
// RequestType, _Bad incorrectly types it as _Self.
class _Self extends MutationSerializable<_Self, String, String> {
  @override
  String get keyGenerator => 'self';
  @override
  Future<dynamic> mutationFn() async => 'ok';
  @override
  String responseHandler(dynamic response) => response as String;
  @override
  OnErrorResults<_Self, String?> errorMapper(_Self request, String error, String? fallback) =>
      OnErrorResults(request: request, error: MutationException(error, 500), fallback: fallback);
}

class _Bad extends MutationSerializable<_Self, String, String> {
  @override
  String get keyGenerator => 'bad';
  @override
  Future<dynamic> mutationFn() async => 'ok';
  @override
  String responseHandler(dynamic response) => response as String;
  @override
  OnErrorResults<_Self, String?> errorMapper(_Self request, String error, String? fallback) =>
      OnErrorResults(request: request, error: MutationException(error, 500), fallback: fallback);
}

void main() {
  test('misdeclared CRTP subclass does not crash when reading mutationKey (regression for #9)', () {
    // The pre-#9 in-class getter performed `MutationKey(this as RequestType)`. With a misdeclared
    // CRTP subclass (RequestType=_Self, instance type=_Bad), `this as _Self` throws a TypeError at
    // runtime. The post-#9 extension resolves T via the declared supertype (T=_Self) and constructs
    // a `MutationKey<_Self, String, String>` without any cast — no crash.
    //
    // If a regression reintroduces the runtime cast (or a similarly unsafe coercion), this test
    // fails because reading `.mutationKey` will throw.
    final bad = _Bad();
    expect(() => bad.mutationKey, returnsNormally);
  });

  test('mutationKey on a correctly-declared CRTP subclass also does not crash', () {
    // Sanity check — the well-formed case must continue to work.
    final self = _Self();
    expect(() => self.mutationKey, returnsNormally);
  });
}
