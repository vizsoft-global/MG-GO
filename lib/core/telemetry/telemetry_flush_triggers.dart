import 'package:flutter/widgets.dart';

/// Local stand-in for Firebase Auth session flips so flush rules stay
/// testable without a Firebase client.
enum AuthChangeEvent { signedIn, signedOut, tokenRefreshed }

/// The five flush triggers, as decisions rather than plumbing.
///
/// The controller owns the timer, the lifecycle observer and the two streams;
/// this class owns *when those mean flush*, so the rules can be tested without a
/// Firebase client, a platform channel or a running app.
class TelemetryFlushTriggers {
  const TelemetryFlushTriggers({
    required this.onFlush,
    required this.onClearSuppression,
  });

  final void Function(String reason) onFlush;
  final void Function() onClearSuppression;

  static const reasonTimer = 'timer';
  static const reasonBackground = 'background';
  static const reasonForeground = 'foreground';
  static const reasonNetworkOnline = 'network_online';
  static const reasonAuth = 'auth';

  /// Idle app, empty queue: stay off the network entirely.
  void timerTick({required bool hasQueuedEvents}) {
    if (hasQueuedEvents) onFlush(reasonTimer);
  }

  void lifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      onFlush(reasonBackground);
    } else if (state == AppLifecycleState.resumed) {
      onFlush(reasonForeground);
    }
  }

  void network({required bool wasOffline, required bool isOffline}) {
    if (wasOffline && !isOffline) onFlush(reasonNetworkOnline);
  }

  /// A token refresh for the same uid is not an auth transition: it must not
  /// clear a `not_a_driver` suppression, or the app would retry every hour.
  void auth({
    required AuthChangeEvent event,
    required String? uid,
    required String? previousUid,
  }) {
    final isTransition = event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.signedOut ||
        uid != previousUid;
    if (!isTransition) return;

    onClearSuppression();
    if (uid != null) onFlush(reasonAuth);
  }

  /// Map a uid change onto [auth] so tests that call [authFromUid] stay
  /// independent of Firebase Auth streams.
  void authFromUid({required String? uid, required String? previousUid}) {
    if (uid == previousUid) {
      auth(
        event: AuthChangeEvent.tokenRefreshed,
        uid: uid,
        previousUid: previousUid,
      );
      return;
    }
    auth(
      event: uid == null ? AuthChangeEvent.signedOut : AuthChangeEvent.signedIn,
      uid: uid,
      previousUid: previousUid,
    );
  }
}
