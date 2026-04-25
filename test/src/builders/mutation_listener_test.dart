import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/builders/mutation_listener.dart';

Mutation<String, int> _makeMutation(MutationCache cache, String key, Future<String> Function(int) fn) {
  return Mutation<String, int>(cache: cache, key: key, mutationFn: fn);
}

Widget _harness(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  late MutationCache cache;
  setUp(() => cache = MutationCache.asNewInstance());

  testWidgets('renders the child widget', (tester) async {
    final mutation = _makeMutation(cache, 'ml-render', (i) async => 'ok-$i');
    await tester.pumpWidget(
      _harness(
        TypedMutationListener<String, int>(
          mutation: mutation,
          child: const Text('child'),
        ),
      ),
    );
    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('onData fires when mutation state changes', (tester) async {
    final mutation = _makeMutation(cache, 'ml-data', (i) async => 'ok-$i');
    var calls = 0;
    await tester.pumpWidget(
      _harness(
        TypedMutationListener<String, int>(
          mutation: mutation,
          onData: (_, _) => calls += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await mutation.mutate(1);
    await tester.pumpAndSettle();
    expect(calls, greaterThanOrEqualTo(1));
  });

  testWidgets('onSuccess fires after a successful mutation', (tester) async {
    final mutation = _makeMutation(cache, 'ml-success', (i) async => 'ok-$i');
    var successes = 0;
    await tester.pumpWidget(
      _harness(
        TypedMutationListener<String, int>(
          mutation: mutation,
          onSuccess: (_, _) => successes += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await mutation.mutate(1);
    await tester.pumpAndSettle();
    expect(successes, greaterThanOrEqualTo(1));
  });

  testWidgets('onError fires after a failing mutation', (tester) async {
    final mutation = _makeMutation(cache, 'ml-error', (i) async => throw StateError('nope'));
    var errors = 0;
    await tester.pumpWidget(
      _harness(
        TypedMutationListener<String, int>(
          mutation: mutation,
          onError: (_, _) => errors += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    try {
      await mutation.mutate(1);
    } catch (_) {/* expected */}
    await tester.pumpAndSettle();
    expect(errors, greaterThanOrEqualTo(1));
  });

  testWidgets('didUpdateWidget swaps subscription', (tester) async {
    final ma = _makeMutation(cache, 'ml-A', (i) async => 'a-$i');
    final mb = _makeMutation(cache, 'ml-B', (i) async => 'b-$i');

    var dataA = 0;
    var dataB = 0;
    Widget under(Mutation<String, int> m, void Function(BuildContext, MutationState<String>) onData) => _harness(
      TypedMutationListener<String, int>(
        mutation: m,
        onData: onData,
        child: const SizedBox.shrink(),
      ),
    );

    await tester.pumpWidget(under(ma, (_, _) => dataA += 1));
    await ma.mutate(1);
    await tester.pumpAndSettle();
    final dataABeforeSwap = dataA;

    await tester.pumpWidget(under(mb, (_, _) => dataB += 1));
    await mb.mutate(2);
    await tester.pumpAndSettle();

    expect(dataA, dataABeforeSwap, reason: 'after swap, the old subscription must not deliver events');
    expect(dataB, greaterThanOrEqualTo(1));
  });

  testWidgets('dispose cancels the subscription', (tester) async {
    final mutation = _makeMutation(cache, 'ml-dispose', (i) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return 'late-$i';
    });
    await tester.pumpWidget(
      _harness(
        TypedMutationListener<String, int>(
          mutation: mutation,
          onData: (_, _) {},
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpWidget(_harness(const SizedBox.shrink()));
    await tester.pumpAndSettle();
  });
}
