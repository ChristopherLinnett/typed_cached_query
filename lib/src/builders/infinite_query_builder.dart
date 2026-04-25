import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';

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

class _TypedInfiniteQueryBuilderState<T, A> extends State<TypedInfiniteQueryBuilder<T, A>> {
  late InfiniteQueryStatus<T, A> _currentState;
  late StreamSubscription<InfiniteQueryStatus<T, A>> _subscription;

  @override
  void initState() {
    super.initState();
    _currentState = widget.query.state;
    _subscription = widget.query.stream.listen((state) => mounted ? setState(() => _currentState = state) : null);
  }

  @override
  void didUpdateWidget(TypedInfiniteQueryBuilder<T, A> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query == oldWidget.query) return;
    _subscription.cancel();
    _currentState = widget.query.state;
    _subscription = widget.query.stream.listen((state) => mounted ? setState(() => _currentState = state) : null);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentState, widget.query.getNextPage, !widget.query.hasNextPage());
  }
}
