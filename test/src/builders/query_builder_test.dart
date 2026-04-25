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
  });

  testWidgets('dispose cancels the subscription so post-dispose stream events do not throw', (tester) async {
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
    // Replace with an empty widget — disposes the State.
    await tester.pumpWidget(_harness(const SizedBox.shrink()));
    // Allow the queryFn future to complete; if dispose forgot to cancel, the late setState would throw.
    await tester.pumpAndSettle();
  });
}
