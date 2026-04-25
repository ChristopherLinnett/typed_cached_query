import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/builders/stream_backed_state.dart';

/// A [TypedInfiniteQueryBuilder] widget that builds its child based on the state of an [InfiniteQuery].
/// This builder only accepts infinite queries created from [InfiniteQueryKey.query()].
class TypedInfiniteQueryBuilder<T, A> extends StatefulWidget {
  /// The infinite query to listen to. Must be created using [InfiniteQueryKey.query()].
  final InfiniteQuery<T, A> query;

  /// The builder function that creates the widget tree based on infinite query state.
  final Widget Function(
    BuildContext context,
    InfiniteQueryStatus<T, A> state,
    Future<InfiniteQueryStatus<T, A>?> Function() fetchNextPage,
    bool hasReachedMax,
  )
  builder;

  /// Creates a [TypedInfiniteQueryBuilder].
  const TypedInfiniteQueryBuilder({super.key, required this.query, required this.builder});

  @override
  State<TypedInfiniteQueryBuilder<T, A>> createState() => _TypedInfiniteQueryBuilderState<T, A>();
}

class _TypedInfiniteQueryBuilderState<T, A> extends State<TypedInfiniteQueryBuilder<T, A>>
    with StreamBackedState<InfiniteQueryStatus<T, A>, TypedInfiniteQueryBuilder<T, A>> {
  @override
  Stream<InfiniteQueryStatus<T, A>> streamFor(TypedInfiniteQueryBuilder<T, A> widget) => widget.query.stream;

  @override
  InfiniteQueryStatus<T, A> initialStateFor(TypedInfiniteQueryBuilder<T, A> widget) => widget.query.state;

  @override
  void onState(InfiniteQueryStatus<T, A> previous, InfiniteQueryStatus<T, A> current) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, currentState, widget.query.getNextPage, !widget.query.hasNextPage());
  }
}
