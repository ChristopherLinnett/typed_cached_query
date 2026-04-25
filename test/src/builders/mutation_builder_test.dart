import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/builders/mutation_builder.dart';

Mutation<String, int> _makeMutation(MutationCache cache, String key, Future<String> Function(int) fn) {
  return Mutation<String, int>(
    cache: cache,
    key: key,
    mutationFn: fn,
  );
}

Widget _harness(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  late MutationCache cache;

  setUp(() {
    cache = MutationCache.asNewInstance();
  });

  testWidgets('renders initial mutation state and exposes the mutate function', (tester) async {
    final mutation = _makeMutation(cache, 'm-exec', (input) async => 'result-$input');

    Future<MutationState<String?>> Function(int)? capturedMutate;
    await tester.pumpWidget(
      _harness(
        TypedMutationBuilder<String, int>(
          mutation: mutation,
          builder: (context, state, mutate) {
            capturedMutate = mutate;
            return Text(state.data ?? 'idle');
          },
        ),
      ),
    );
    expect(find.text('idle'), findsOneWidget);
    expect(capturedMutate, isNotNull);

    await capturedMutate!(7);
    await tester.pumpAndSettle();
    expect(find.text('result-7'), findsOneWidget);
  });

  testWidgets('didUpdateWidget swaps subscription when the mutation changes', (tester) async {
    final m1 = _makeMutation(cache, 'm-1', (i) async => '1-$i');
    final m2 = _makeMutation(cache, 'm-2', (i) async => '2-$i');

    Widget under(Mutation<String, int> m) => _harness(
      TypedMutationBuilder<String, int>(
        mutation: m,
        builder: (context, state, mutate) => Text(state.data ?? '?'),
      ),
    );

    await tester.pumpWidget(under(m1));
    await m1.mutate(1);
    await tester.pumpAndSettle();
    expect(find.text('1-1'), findsOneWidget);

    await tester.pumpWidget(under(m2));
    await m2.mutate(9);
    await tester.pumpAndSettle();
    expect(find.text('2-9'), findsOneWidget);
  });

  testWidgets('dispose cancels the subscription so post-dispose events do not throw', (tester) async {
    final mutation = _makeMutation(cache, 'm-dispose', (i) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return 'late-$i';
    });

    await tester.pumpWidget(
      _harness(
        TypedMutationBuilder<String, int>(
          mutation: mutation,
          builder: (context, state, mutate) => Text(state.data ?? '?'),
        ),
      ),
    );
    await tester.pumpWidget(_harness(const SizedBox.shrink()));
    await tester.pumpAndSettle();
  });
}
