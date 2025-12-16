import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';

/// A [TypedQueryBuilder] widget that builds its child based on the state of a [Query].
/// This builder only accepts queries created from [QueryKey.query()].
class TypedQueryBuilder<T> extends StatefulWidget {
  /// The query to listen to. Must be created using [QueryKey.query()].
  final Query<T> query;

  /// The builder function that creates the widget tree based on query state.
  final Widget Function(BuildContext context, QueryStatus<T> state) builder;

  /// Creates a [TypedQueryBuilder].
  const TypedQueryBuilder({super.key, required this.query, required this.builder});

  @override
  State<TypedQueryBuilder<T>> createState() => _TypedQueryBuilderState<T>();
}

class _TypedQueryBuilderState<T> extends State<TypedQueryBuilder<T>> {
  late QueryStatus<T> _currentState;
  late StreamSubscription<QueryStatus<T>> _subscription;

  @override
  void initState() {
    super.initState();
    _currentState = widget.query.state;
    _subscription = widget.query.stream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });
  }

  @override
  void didUpdateWidget(TypedQueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _subscription.cancel();
      _currentState = widget.query.state;
      _subscription = widget.query.stream.listen((state) {
        if (mounted) {
          setState(() {
            _currentState = state;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentState);
  }
}
