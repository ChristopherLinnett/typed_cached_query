import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/builders/query_builder.dart';

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

  setUp(() {
    cache = CachedQuery.asNewInstance();
  });

  testWidgets('renders the initial query state and rebuilds on stream emission', (tester) async {
    final completer = await Future.value('first');
    final query = _makeQuery(cache, 'q-emit', () async => completer);

    var lastSeen = '';
    await tester.pumpWidget(
      _harness(
        TypedQueryBuilder<String>(
          query: query,
          builder: (context, state) {
            lastSeen = state.data ?? '';
            return Text(state.data ?? 'idle');
          },
        ),
      ),
    );
    expect(find.text('idle'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(lastSeen, 'first');
    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('didUpdateWidget cancels old subscription and subscribes to the new query', (tester) async {
    final queryA = _makeQuery(cache, 'q-A', () async => 'A');
    final queryB = _makeQuery(cache, 'q-B', () async => 'B');

    Widget under(Query<String> q) => _harness(
      TypedQueryBuilder<String>(
        query: q,
        builder: (context, state) => Text(state.data ?? '?'),
      ),
    );

    await tester.pumpWidget(under(queryA));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);

    await tester.pumpWidget(under(queryB));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);

    // Drive a state change on the OLD query and assert the UI does not react — proves the
    // old subscription is gone, not just that the new query happens to render the same value.
    queryA.update((_) => 'A-updated');
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A-updated'), findsNothing);
  });

  testWidgets('dispose-time mounted guard suppresses post-dispose setState', (tester) async {
    // The widget guards setState with `if (mounted)`, so this test exercises the mounted-guard
    // path — it does not (and cannot from outside the widget) directly observe StreamSubscription
    // cancellation. A leaked subscription would be silent here; what we are protecting against is
    // a thrown exception from setState-after-dispose.
    final query = _makeQuery(cache, 'q-dispose', () async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return 'late';
    });

    await tester.pumpWidget(
      _harness(
        TypedQueryBuilder<String>(
          query: query,
          builder: (context, state) => Text(state.data ?? '?'),
        ),
      ),
    );
    await tester.pumpWidget(_harness(const SizedBox.shrink()));
    await tester.pumpAndSettle();
  });
}
