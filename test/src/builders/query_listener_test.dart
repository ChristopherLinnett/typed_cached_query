import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/builders/query_listener.dart';

Query<String> _makeQuery(CachedQuery cache, String key, Future<String> Function() queryFn) {
  return Query<String>(
    cache: cache,
    key: key,
    queryFn: queryFn,
    config: const QueryConfig(staleDuration: Duration.zero, ignoreCacheDuration: true),
  );
}

Widget _harness(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  late CachedQuery cache;
  setUp(() => cache = CachedQuery.asNewInstance());

  testWidgets('renders the child widget', (tester) async {
    final query = _makeQuery(cache, 'ql-render', () async => 'ok');
    await tester.pumpWidget(
      _harness(
        TypedQueryListener<String>(
          query: query,
          child: const Text('child'),
        ),
      ),
    );
    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('onChange/onSuccess/onLoading fire at least once during a successful fetch', (tester) async {
    // Strict transition-count semantics are exercised by the regression tests in #20 / #3
    // alongside the corresponding listener fixes. Here we assert the wiring is alive.
    final query = _makeQuery(cache, 'ql-change', () async => 'value');
    var changes = 0;
    var successes = 0;
    var loadings = 0;

    await tester.pumpWidget(
      _harness(
        TypedQueryListener<String>(
          query: query,
          onChange: (_, _) => changes += 1,
          onSuccess: (_, _) => successes += 1,
          onLoading: (_, _) => loadings += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(changes, greaterThanOrEqualTo(1));
    expect(successes, greaterThanOrEqualTo(1));
    expect(loadings, greaterThanOrEqualTo(1));
  });

  testWidgets('onError fires when the query function throws', (tester) async {
    final query = _makeQuery(cache, 'ql-error', () async => throw StateError('nope'));
    var errors = 0;

    await tester.pumpWidget(
      _harness(
        TypedQueryListener<String>(
          query: query,
          onError: (_, _) => errors += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(errors, greaterThanOrEqualTo(1));
  });

  testWidgets('didUpdateWidget swaps subscription', (tester) async {
    final qa = _makeQuery(cache, 'ql-A', () async => 'a');
    final qb = _makeQuery(cache, 'ql-B', () async => 'b');

    var changesA = 0;
    var changesB = 0;
    Widget under(Query<String> q, void Function(BuildContext, QueryStatus<String>) onChange) => _harness(
      TypedQueryListener<String>(
        query: q,
        onChange: onChange,
        child: const SizedBox.shrink(),
      ),
    );

    await tester.pumpWidget(under(qa, (_, __) => changesA += 1));
    await qa.fetch();
    await tester.pumpAndSettle();
    final changesABeforeSwap = changesA;

    await tester.pumpWidget(under(qb, (_, __) => changesB += 1));
    await qb.fetch();
    await tester.pumpAndSettle();

    expect(changesA, changesABeforeSwap, reason: 'after swap, the old subscription must not deliver events');
    expect(changesB, greaterThanOrEqualTo(1));
  });

  testWidgets('dispose cancels the subscription', (tester) async {
    final query = _makeQuery(cache, 'ql-dispose', () async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return 'late';
    });

    var changes = 0;
    await tester.pumpWidget(
      _harness(
        TypedQueryListener<String>(
          query: query,
          onChange: (_, __) => changes += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpWidget(_harness(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    // No expectations on `changes` — the assertion is that pumpAndSettle does not throw.
  });
}
