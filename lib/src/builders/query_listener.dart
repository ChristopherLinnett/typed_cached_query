import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';

/// A [TypedQueryListener] widget that listens to query state changes and calls callbacks.
/// This listener only accepts queries created from [QueryKey.query()].
class TypedQueryListener<T> extends StatefulWidget {
  /// The query to listen to. Must be created using [QueryKey.query()].
  final Query<T> query;

  /// The child widget to render.
  final Widget child;

  /// Called when the query state changes.
  final void Function(BuildContext context, QueryStatus<T> state)? onChange;

  /// Called when the query encounters an error.
  final void Function(BuildContext context, QueryStatus<T> state)? onError;

  /// Called when the query loads successfully.
  final void Function(BuildContext context, QueryStatus<T> state)? onSuccess;

  /// Called when the query starts loading.
  final void Function(BuildContext context, QueryStatus<T> state)? onLoading;

    /// Called when the query starts loading.
  final void Function(BuildContext context, QueryStatus<T> state)? onRefetching;

  /// Creates a [TypedQueryListener].
  const TypedQueryListener({super.key, required this.query, required this.child, this.onChange, this.onError, this.onSuccess, this.onLoading, this.onRefetching});

  @override
  State<TypedQueryListener<T>> createState() => _TypedQueryListenerState<T>();
}

class _TypedQueryListenerState<T> extends State<TypedQueryListener<T>> {
  late QueryStatus<T> _previousState;
  late StreamSubscription<QueryStatus<T>> _subscription;

  @override
  void initState() {
    super.initState();
    _previousState = widget.query.state;
    _subscription = widget.query.stream.listen((state) {
      if (mounted) {
        _handleStateChange(_previousState, state);
        _previousState = state;
      }
    });
  }

  @override
  void didUpdateWidget(TypedQueryListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _subscription.cancel();
      _previousState = widget.query.state;
      _subscription = widget.query.stream.listen((state) {
        if (mounted) {
          _handleStateChange(_previousState, state);
          _previousState = state;
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _handleStateChange(QueryStatus<T> previous, QueryStatus<T> current) {
    widget.onChange?.call(context, current);

    if (!previous.isError && current.isError && widget.onError != null) return widget.onError!(context, current);
    if (!previous.isSuccess && current.isSuccess && widget.onSuccess != null) return widget.onSuccess!(context, current);
    if (!previous.isLoading && current.isLoading && widget.onLoading != null) return widget.onLoading!(context, current);
    if (previous.data != null && current.isLoading && widget.onRefetching != null) return widget.onRefetching!(context, current);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
