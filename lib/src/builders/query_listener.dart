import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/builders/stream_backed_state.dart';

/// A [TypedQueryListener] widget that listens to query state changes and calls callbacks.
///
/// The [query] is normally produced by calling `request.query(...)` on a [QuerySerializable]
/// (e.g. `getUserQuery.query()`). The `*Key.query(...)` form is still accepted — it's the same
/// call under the hood.
///
/// ## Choosing between the listener callbacks and the data-pipeline callbacks
///
/// `request.query(onSuccess: ..., onError: ...)` and the listener's [onSuccess] / [onError] /
/// [onLoading] / [onRefetching] / [onChange] callbacks fire at *different layers* — they are
/// not duplicates:
///
/// - **`Query.onSuccess` / `Query.onError`** (passed via `request.query(...)`) — data-pipeline
///   hooks owned by `cached_query`. Signature `(T data)` / `(dynamic error)`. No
///   [BuildContext]. Use for analytics, persistence, side effects that don't touch the widget
///   tree. Fires once per cached_query lifecycle event regardless of whether any widget is
///   listening.
/// - **`TypedQueryListener.onSuccess` / `onError` / etc.** — widget-tree hooks owned by this
///   listener. Signature `(BuildContext context, QueryStatus<T> state)`. Use for
///   [Navigator.push], `ScaffoldMessenger.showSnackBar`, focus changes — anything that needs a
///   context or only matters while this listener is mounted.
///
/// In short: data-pipeline → no context → use `request.query(...)`; widget reaction → needs
/// context → use the listener callback.
class TypedQueryListener<T> extends StatefulWidget {
  /// The query to listen to. Typically built via `request.query(...)`.
  final Query<T> query;

  /// The child widget to render.
  final Widget child;

  /// Widget-tree hook called when the query state changes. Receives [BuildContext] for
  /// navigation / messenger / focus side effects. See class dartdoc for the contrast with
  /// `Query.onSuccess` / `Query.onError` (data-pipeline hooks without context).
  final void Function(BuildContext context, QueryStatus<T> state)? onChange;

  /// Widget-tree hook called when the query transitions into an error state.
  final void Function(BuildContext context, QueryStatus<T> state)? onError;

  /// Widget-tree hook called when the query transitions into a success state.
  final void Function(BuildContext context, QueryStatus<T> state)? onSuccess;

  /// Widget-tree hook called when the query starts loading from a no-data state (cold start).
  final void Function(BuildContext context, QueryStatus<T> state)? onLoading;

  /// Widget-tree hook called when the query starts a refetch — i.e. transitions into loading
  /// while data is already present.
  final void Function(BuildContext context, QueryStatus<T> state)? onRefetching;

  /// Creates a [TypedQueryListener].
  const TypedQueryListener({
    super.key,
    required this.query,
    required this.child,
    this.onChange,
    this.onError,
    this.onSuccess,
    this.onLoading,
    this.onRefetching,
  });

  @override
  State<TypedQueryListener<T>> createState() => _TypedQueryListenerState<T>();
}

class _TypedQueryListenerState<T> extends State<TypedQueryListener<T>>
    with StreamBackedState<QueryStatus<T>, TypedQueryListener<T>> {
  @override
  Stream<QueryStatus<T>> streamFor(TypedQueryListener<T> widget) => widget.query.stream;

  @override
  QueryStatus<T> initialStateFor(TypedQueryListener<T> widget) => widget.query.state;

  @override
  void onState(QueryStatus<T> previous, QueryStatus<T> current) {
    widget.onChange?.call(context, current);

    if (!previous.isError && current.isError && widget.onError != null) return widget.onError!(context, current);
    if (!previous.isSuccess && current.isSuccess && widget.onSuccess != null) return widget.onSuccess!(context, current);
    // Refetch must be checked before onLoading: a refetch satisfies the !previous.isLoading && current.isLoading
    // predicate, so without this earlier branch onRefetching would be unreachable. A query that previously
    // succeeded with null data (nullable return type / void-shaped success) is still a refetch — gate on
    // previous.isSuccess as well as previous.data != null.
    if ((previous.isSuccess || previous.data != null) && !previous.isLoading && current.isLoading && widget.onRefetching != null) {
      return widget.onRefetching!(context, current);
    }
    if (!previous.isLoading && current.isLoading && widget.onLoading != null) return widget.onLoading!(context, current);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
