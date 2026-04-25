import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/builders/stream_backed_state.dart';

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

class _TypedMutationBuilderState<T, R> extends State<TypedMutationBuilder<T, R>>
    with StreamBackedState<MutationState<T>, TypedMutationBuilder<T, R>> {
  @override
  Stream<MutationState<T>> streamFor(TypedMutationBuilder<T, R> widget) => widget.mutation.stream;

  @override
  MutationState<T> initialStateFor(TypedMutationBuilder<T, R> widget) => widget.mutation.state;

  @override
  void onState(MutationState<T> previous, MutationState<T> current) {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, currentState, widget.mutation.mutate);
}
