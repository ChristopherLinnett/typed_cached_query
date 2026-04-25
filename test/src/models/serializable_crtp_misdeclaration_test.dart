import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CRTP misdeclaration is rejected by the analyzer (regression for #9)', () async {
    // Run `dart analyze` against the deliberately-broken fixture and assert the expected
    // diagnostics surface, proving the type-safe MutationSerializableExtension prevents what was
    // previously a runtime cast failure.
    final result = await Process.run(
      'dart',
      ['analyze', 'test/fixtures/bad_mutation_serializable_crtp.dart'],
      workingDirectory: Directory.current.path,
    );

    final output = '${result.stdout}\n${result.stderr}';

    expect(result.exitCode, isNot(0), reason: 'dart analyze must fail on the misdeclared CRTP fixture\nOutput:\n$output');
    expect(
      output,
      contains("doesn't conform to the bound"),
      reason: 'Expected the F-bound violation diagnostic.\nOutput:\n$output',
    );
    expect(
      output,
      contains("can't be assigned to a variable of type"),
      reason: 'Expected the assignment-type-mismatch diagnostic.\nOutput:\n$output',
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
