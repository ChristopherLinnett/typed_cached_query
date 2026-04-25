// Fixture: a misdeclared CRTP subclass of MutationSerializable.
//
// Demonstrates that the type-safe `MutationSerializableExtension.mutationKey` (introduced in #9
// to replace the runtime `this as RequestType` cast) prevents a misdeclared CRTP subclass from
// being assignable to a MutationKey typed for ITSELF. The extension still resolves (because the
// subclass IS a MutationSerializable<Self, ...> via inheritance), but the resulting MutationKey
// is typed for `_Self` — so assigning it to `MutationKey<_Bad, ...>` is a static type error.
//
// This file intentionally fails `dart analyze`. It is excluded from the test runner because the
// filename does not end in `_test.dart`. The companion test
// `test/src/models/serializable_crtp_misdeclaration_test.dart` runs `dart analyze` against this
// fixture and asserts the expected diagnostic is produced.
//
// See: typed_cached_query/issues/58.
//
// ignore_for_file: unused_local_variable, unused_element

import 'package:typed_cached_query/src/errors/query_exception.dart';
import 'package:typed_cached_query/src/models/mutation_key.dart';
import 'package:typed_cached_query/src/models/serializable.dart';

class _Self extends MutationSerializable<_Self, String, String> {
  @override
  String get keyGenerator => 'self';
  @override
  Future<String> mutationFn() async => 'ok';
  @override
  String responseHandler(dynamic response) => response as String;
  @override
  OnErrorResults<_Self, String?> errorMapper(_Self request, String error, String? fallback) =>
      OnErrorResults(request: request, error: MutationException(error, 500), fallback: fallback);
}

// Misdeclared CRTP: the F-bounded RequestType is _Self, but the implementing class is _Bad.
class _Bad extends MutationSerializable<_Self, String, String> {
  @override
  String get keyGenerator => 'bad';
  @override
  Future<String> mutationFn() async => 'ok';
  @override
  String responseHandler(dynamic response) => response as String;
  @override
  OnErrorResults<_Self, String?> errorMapper(_Self request, String error, String? fallback) =>
      OnErrorResults(request: request, error: MutationException(error, 500), fallback: fallback);
}

void main() {
  final bad = _Bad();
  // Expected analyzer error: assigning a MutationKey typed for _Self into MutationKey<_Bad, ...>
  // is a static type mismatch. Pre-#9 (with `this as RequestType` cast) this was a runtime crash;
  // post-#9 it surfaces here at compile time.
  final MutationKey<_Bad, String, String> key = bad.mutationKey;
}
