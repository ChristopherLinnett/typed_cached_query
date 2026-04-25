import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_cached_query/src/builders/infinite_query_builder.dart';

InfiniteQuery<String, int> _makeInfinite(CachedQuery cache, String key, {required int maxPage, String prefix = 'page'}) {
  return InfiniteQuery<String, int>(
    cache: cache,
    key: key,
    queryFn: (page) async => '$prefix-$page',
    getNextArg: (data) {
      if (data == null || data.pages.isEmpty) return 1;
      final next = data.args.last + 1;
      return next > maxPage ? null : next;
    },
    config: const QueryConfig(staleDuration: Duration.zero, ignoreCacheDuration: true),
  );
}

Widget _harness(Widget child) => Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  late CachedQuery cache;

  setUp(() {
    cache = CachedQuery.asNewInstance();
  });

  testWidgets('renders state and rebuilds on stream emission', (tester) async {
    final query = _makeInfinite(cache, 'iq-render', maxPage: 2);

    await tester.pumpWidget(
      _harness(
        TypedInfiniteQueryBuilder<String, int>(
          query: query,
          builder: (context, state, fetchNext, hasReachedMax) {
            final pages = state.data?.pages.join(',') ?? 'idle';
            return Text(pages);
          },
        ),
      ),
    );
    expect(find.text('idle'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('page-1'), findsOneWidget);
  });

  testWidgets('fetchNextPage callback advances pagination', (tester) async {
    final query = _makeInfinite(cache, 'iq-paginate', maxPage: 3);

    Future<InfiniteQueryStatus<String, int>?> Function()? capturedNext;
    await tester.pumpWidget(
      _harness(
        TypedInfiniteQueryBuilder<String, int>(
          query: query,
          builder: (context, state, fetchNext, hasReachedMax) {
            capturedNext = fetchNext;
            return Text(state.data?.pages.length.toString() ?? '0');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    await capturedNext!();
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('didUpdateWidget swaps subscription when the query changes', (tester) async {
    final qa = _makeInfinite(cache, 'iq-A', maxPage: 2, prefix: 'A');
    final qb = _makeInfinite(cache, 'iq-B', maxPage: 2, prefix: 'B');

    Widget under(InfiniteQuery<String, int> q) => _harness(
      TypedInfiniteQueryBuilder<String, int>(
        query: q,
        builder: (context, state, fetchNext, hasReachedMax) => Text(state.data?.pages.firstOrNull ?? '?'),
      ),
    );

    await tester.pumpWidget(under(qa));
    await tester.pumpAndSettle();
    expect(find.text('A-1'), findsOneWidget);

    await tester.pumpWidget(under(qb));
    await tester.pumpAndSettle();
    expect(find.text('B-1'), findsOneWidget);

    // Drive the OLD query (qa) and assert the UI does not react — proves the swap dropped the
    // old subscription rather than just ending up at the same value by coincidence.
    await qa.refetch();
    await tester.pumpAndSettle();
    expect(find.text('B-1'), findsOneWidget);
    expect(find.text('A-1'), findsNothing);
  });

  testWidgets('dispose-time mounted guard suppresses post-dispose setState', (tester) async {
    final query = _makeInfinite(cache, 'iq-dispose', maxPage: 1);
    await tester.pumpWidget(
      _harness(
        TypedInfiniteQueryBuilder<String, int>(
          query: query,
          builder: (context, state, fetchNext, hasReachedMax) => const Text('x'),
        ),
      ),
    );
    await tester.pumpWidget(_harness(const SizedBox.shrink()));
    await tester.pumpAndSettle();
  });
}
