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

Query<String?> _makeNullableQuery(CachedQuery cache, String key, Future<String?> Function() queryFn) {
  return Query<String?>(
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

  testWidgets('onRefetching fires when refetching a query that already has data', (tester) async {
    final query = _makeQuery(cache, 'ql-refetch', () async => 'value');

    var loadings = 0;
    var refetchings = 0;

    await tester.pumpWidget(
      _harness(
        TypedQueryListener<String>(
          query: query,
          onLoading: (_, _) => loadings += 1,
          onRefetching: (_, _) => refetchings += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    // Cold start: stream auto-fetches via onListen.
    await tester.pumpAndSettle();
    expect(loadings, greaterThanOrEqualTo(1), reason: 'cold-start fetch must fire onLoading');
    expect(refetchings, 0, reason: 'onRefetching must not fire on the cold start when there is no prior data');

    // Refetch: data is populated, so the listener should classify the next loading transition as refetching.
    final loadingsBeforeRefetch = loadings;
    await query.refetch();
    await tester.pumpAndSettle();

    expect(refetchings, greaterThanOrEqualTo(1), reason: 'a refetch with data present must fire onRefetching');
    expect(loadings, loadingsBeforeRefetch, reason: 'onLoading must not fire on a refetch when data is already present');
  });

  testWidgets('onRefetching fires when refetching a query whose previous success had null data', (tester) async {
    // Regression for the predicate that used `previous.data != null` only — a successful query
    // with a nullable return type that completed with null was being misclassified as a cold start.
    final query = _makeNullableQuery(cache, 'ql-refetch-null', () async => null);

    var loadings = 0;
    var refetchings = 0;

    await tester.pumpWidget(
      _harness(
        TypedQueryListener<String?>(
          query: query,
          onLoading: (_, _) => loadings += 1,
          onRefetching: (_, _) => refetchings += 1,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loadingsAfterColdStart = loadings;
    final refetchingsAfterColdStart = refetchings;
    expect(loadingsAfterColdStart, greaterThanOrEqualTo(1), reason: 'cold-start fetch must fire onLoading even when data resolves to null');
    expect(refetchingsAfterColdStart, 0, reason: 'cold start cannot be a refetch');

    // Refetch — previous state was Success(data: null). The predicate should still classify this as a refetch.
    await query.refetch();
    await tester.pumpAndSettle();

    expect(refetchings, greaterThan(refetchingsAfterColdStart), reason: 'refetching from a successful-null state must fire onRefetching');
    expect(loadings, loadingsAfterColdStart, reason: 'onLoading must not fire on a refetch even when previous data was null');
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

    // Drive the OLD query and assert the old onChange remains silent.
    qa.update((_) => 'a-updated');
    await tester.pumpAndSettle();
    expect(changesA, changesABeforeSwap);
  });

  testWidgets('dispose-time mounted guard suppresses post-dispose setState', (tester) async {
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
