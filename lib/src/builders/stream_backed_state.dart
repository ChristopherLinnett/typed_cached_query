import 'dart:async';
import 'package:flutter/widgets.dart';

/// Internal mixin that owns the subscription lifecycle for State classes that listen to a stream
/// produced by a property of their widget.
///
/// Subclasses provide [streamFor], [initialStateFor], and [onState], and the mixin handles:
/// - subscribing in [initState]
/// - cancelling and resubscribing in [didUpdateWidget] when the stream identity changes
/// - cancelling in [dispose]
/// - guarding stream events behind [State.mounted] before propagating to [onState]
///
/// [onState] receives the previous and the new state; [currentState] always returns the latest.
mixin StreamBackedState<S, W extends StatefulWidget> on State<W> {
  late S _state;
  late StreamSubscription<S> _subscription;

  /// Returns the stream to listen to for the given widget instance.
  Stream<S> streamFor(W widget);

  /// Returns the state to seed [currentState] with on (re-)subscribe — typically the stream's
  /// current value.
  S initialStateFor(W widget);

  /// Called once per stream event after [currentState] has been updated to [current].
  void onState(S previous, S current);

  /// The latest state delivered by the stream (or seeded by [initialStateFor]).
  S get currentState => _state;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (streamFor(widget) != streamFor(oldWidget)) {
      _subscription.cancel();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _subscribe() {
    _state = initialStateFor(widget);
    _subscription = streamFor(widget).listen((next) {
      if (!mounted) return;
      final previous = _state;
      _state = next;
      onState(previous, next);
    });
  }
}
