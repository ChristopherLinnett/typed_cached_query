import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';

/// A [TypedMutationBuilder] widget that builds its child based on the state of a [Mutation].
/// This builder only accepts mutations created from [MutationKey.definition()].
class TypedMutationBuilder<T, R> extends StatefulWidget {
  /// The mutation to listen to. Must be created using [MutationKey.definition()].
  final Mutation<T, R> mutation;

  /// The builder function that creates the widget tree based on mutation state.
  final Widget Function(BuildContext context, MutationState<T> state, Future<MutationState<T?>> Function(R) mutate) builder;

  /// Creates a [TypedMutationBuilder].
  const TypedMutationBuilder({super.key, required this.mutation, required this.builder});

  @override
  State<TypedMutationBuilder<T, R>> createState() => _TypedMutationBuilderState<T, R>();
}

class _TypedMutationBuilderState<T, R> extends State<TypedMutationBuilder<T, R>> {
  late MutationState<T> _currentState;
  late StreamSubscription<MutationState<T>> _subscription;

  @override
  void initState() {
    super.initState();
    _currentState = widget.mutation.state;
    _subscription = widget.mutation.stream.listen((state) => mounted ? setState(() => _currentState = state) : null);
  }

  @override
  void didUpdateWidget(TypedMutationBuilder<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mutation == oldWidget.mutation) return;
    _subscription.cancel();
    _currentState = widget.mutation.state;
    _subscription = widget.mutation.stream.listen((state) => mounted ? setState(() => _currentState = state) : null);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _currentState, widget.mutation.mutate);
  }
}
