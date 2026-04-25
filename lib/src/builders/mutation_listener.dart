import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/builders/stream_backed_state.dart';

/// A [TypedMutationListener] widget that listens to mutation state changes and calls callbacks.
/// This listener only accepts mutations created from [MutationKey.definition()].
class TypedMutationListener<T, R> extends StatefulWidget {
  /// The mutation to listen to. Must be created using [MutationKey.definition()].
  final Mutation<T, R> mutation;

  /// The child widget to render.
  final Widget child;

  /// Called when the mutation state changes.
  final void Function(BuildContext context, MutationState<T> state)? onData;

  /// Called when the mutation encounters an error.
  final void Function(BuildContext context, MutationState<T> state)? onError;

  /// Called when the mutation completes successfully.
  final void Function(BuildContext context, MutationState<T> state)? onSuccess;

  /// Called when the mutation starts loading.
  final void Function(BuildContext context, MutationState<T> state)? onLoading;

  /// Creates a [TypedMutationListener].
  const TypedMutationListener({
    super.key,
    required this.mutation,
    required this.child,
    this.onData,
    this.onError,
    this.onSuccess,
    this.onLoading,
  });

  @override
  State<TypedMutationListener<T, R>> createState() => _TypedMutationListenerState<T, R>();
}

class _TypedMutationListenerState<T, R> extends State<TypedMutationListener<T, R>>
    with StreamBackedState<MutationState<T>, TypedMutationListener<T, R>> {
  @override
  Stream<MutationState<T>> streamFor(TypedMutationListener<T, R> widget) => widget.mutation.stream;

  @override
  MutationState<T> initialStateFor(TypedMutationListener<T, R> widget) => widget.mutation.state;

  @override
  void onState(MutationState<T> previous, MutationState<T> current) {
    widget.onData?.call(context, current);

    // Transition-only semantics: only fire on the leading edge of a state change.
    if (!previous.isError && current.isError && widget.onError != null) {
      widget.onError!(context, current);
    } else if (!previous.isSuccess && current.isSuccess && widget.onSuccess != null) {
      widget.onSuccess!(context, current);
    } else if (!previous.isLoading && current.isLoading && widget.onLoading != null) {
      widget.onLoading!(context, current);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
