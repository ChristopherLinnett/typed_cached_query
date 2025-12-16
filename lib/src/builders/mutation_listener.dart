import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:cached_query_flutter/cached_query_flutter.dart';

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
  const TypedMutationListener({super.key, required this.mutation, required this.child, this.onData, this.onError, this.onSuccess, this.onLoading});

  @override
  State<TypedMutationListener<T, R>> createState() => _TypedMutationListenerState<T, R>();
}

class _TypedMutationListenerState<T, R> extends State<TypedMutationListener<T, R>> {
  late MutationState<T> _previousState;
  late StreamSubscription<MutationState<T>> _subscription;

  @override
  void initState() {
    super.initState();
    _previousState = widget.mutation.state;
    _subscription = widget.mutation.stream.listen((state) {
      if (mounted) {
        _handleStateChange(_previousState, state);
        _previousState = state;
      }
    });
  }

  @override
  void didUpdateWidget(TypedMutationListener<T, R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mutation != oldWidget.mutation) {
      _subscription.cancel();
      _previousState = widget.mutation.state;
      _subscription = widget.mutation.stream.listen((state) {
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

  void _handleStateChange(MutationState<T> previous, MutationState<T> current) {
    widget.onData?.call(context, current);

    if (current.isError && widget.onError != null) {
      widget.onError!(context, current);
    } else if (current.isSuccess && widget.onSuccess != null) {
      widget.onSuccess!(context, current);
    } else if (current.isLoading && widget.onLoading != null) {
      widget.onLoading!(context, current);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
