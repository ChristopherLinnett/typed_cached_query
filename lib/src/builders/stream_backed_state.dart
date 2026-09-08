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

  /// What this state's subscription is FOR: the query's or mutation's key. Compared in
  /// [didUpdateWidget] to decide whether the subscription must move.
  ///
  /// Never compare the streams themselves: `Subject.stream` (rxdart) returns a new wrapper
  /// object on every call, so two reads of the same query's `stream` are never equal, and a
  /// state that compared them cancelled and re-subscribed on EVERY parent rebuild. Re-listening
  /// to a `Query` runs its listen-to-fetch path, which refetches whenever the data is stale, so
  /// any surface with a rebuilding ancestor refetched every query under it once per stale
  /// window — one screen with four builders became a request a second.
  ///
  /// The KEY rather than the instance, because the cache may hand out a fresh `Query` object
  /// for the same key (it does whenever the config it is asked for differs, storage-backed
  /// queries included) while every instance for a key shares one controller and keeps
  /// following it; the subscription already held is as live as a new one would be, and costs
  /// no fetch.
  Object subscriptionIdentityFor(W widget);

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
    if (!identical(subscriptionIdentityFor(widget), subscriptionIdentityFor(oldWidget))) {
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
