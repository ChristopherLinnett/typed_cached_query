import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';
import 'package:typed_cached_query/src/builders/stream_backed_state.dart';

/// A [TypedMutationListener] widget that listens to mutation state changes and calls callbacks.
///
/// The [mutation] is normally produced by calling `request.definition(...)` on a
/// [MutationSerializable] (e.g. `updateUserMutation.definition()`). The `*Key.definition(...)`
/// form is still accepted — it's the same call under the hood.
///
/// ## Choosing between the listener callbacks and the data-pipeline callbacks
///
/// `request.definition(onSuccess: ..., onError: ...)` and the listener's [onSuccess] /
/// [onError] / [onLoading] / [onData] callbacks fire at *different layers* — they are not
/// duplicates:
///
/// - **`Mutation.onSuccess` / `Mutation.onError`** (passed via `request.definition(...)` or
///   `request.mutate(...)`) — data-pipeline hooks owned by `cached_query`. Signatures take the
///   raw payload and the originating request. No [BuildContext]. Use for analytics, cache
///   invalidation, persistence — side effects that don't touch the widget tree.
/// - **`TypedMutationListener.onSuccess` / `onError` / etc.** — widget-tree hooks owned by this
///   listener. Signature `(BuildContext context, MutationState<T> state)`. Use for
///   [Navigator.push], `ScaffoldMessenger.showSnackBar`, focus changes — anything that needs a
///   context or only matters while this listener is mounted.
///
/// In short: data-pipeline → no context → use `request.definition(...)`; widget reaction →
/// needs context → use the listener callback.
class TypedMutationListener<T, R> extends StatefulWidget {
  /// The mutation to listen to. Typically built via `request.definition(...)`.
  final Mutation<T, R> mutation;

  /// The child widget to render.
  final Widget child;

  /// Widget-tree hook called when the mutation state changes. Receives [BuildContext] for
  /// navigation / messenger / focus side effects. See class dartdoc for the contrast with
  /// `Mutation.onSuccess` / `Mutation.onError` (data-pipeline hooks without context).
  final void Function(BuildContext context, MutationState<T> state)? onData;

  /// Widget-tree hook called when the mutation transitions into an error state.
  final void Function(BuildContext context, MutationState<T> state)? onError;

  /// Widget-tree hook called when the mutation transitions into a success state.
  final void Function(BuildContext context, MutationState<T> state)? onSuccess;

  /// Widget-tree hook called when the mutation transitions into a loading state.
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
