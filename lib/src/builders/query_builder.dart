import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/builders/stream_backed_state.dart';

/// A [TypedQueryBuilder] widget that builds its child based on the state of a [Query].
///
/// The [query] is normally produced by calling `request.query(...)` on a
/// [QuerySerializable] (e.g. `getUserQuery.query(onSuccess: ..., config: ...)`). The
/// `*Key.query(...)` form is still accepted — it's the same call under the hood.
class TypedQueryBuilder<T> extends StatefulWidget {
  /// The query to listen to. Typically built via `request.query(...)`.
  final Query<T> query;

  /// The builder function that creates the widget tree based on query state.
  final Widget Function(BuildContext context, QueryStatus<T> state) builder;

  /// Creates a [TypedQueryBuilder].
  const TypedQueryBuilder({super.key, required this.query, required this.builder});

  @override
  State<TypedQueryBuilder<T>> createState() => _TypedQueryBuilderState<T>();
}

class _TypedQueryBuilderState<T> extends State<TypedQueryBuilder<T>>
    with StreamBackedState<QueryStatus<T>, TypedQueryBuilder<T>> {
  @override
  Stream<QueryStatus<T>> streamFor(TypedQueryBuilder<T> widget) => widget.query.stream;

  @override
  QueryStatus<T> initialStateFor(TypedQueryBuilder<T> widget) => widget.query.state;

  @override
  void onState(QueryStatus<T> previous, QueryStatus<T> current) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, currentState);
}
