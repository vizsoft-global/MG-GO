import 'package:dpd_userapp/core/telemetry/telemetry_flush_triggers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<String> reasons;
  late int cleared;
  late TelemetryFlushTriggers triggers;

  setUp(() {
    reasons = [];
    cleared = 0;
    triggers = TelemetryFlushTriggers(
      onFlush: reasons.add,
      onClearSuppression: () => cleared++,
    );
  });

  test('all five triggers fire a flush', () {
    triggers.timerTick(hasQueuedEvents: true);
    triggers.lifecycle(AppLifecycleState.paused);
    triggers.lifecycle(AppLifecycleState.resumed);
    triggers.network(wasOffline: true, isOffline: false);
    triggers.auth(
      event: AuthChangeEvent.signedIn,
      uid: 'uid-1',
      previousUid: null,
    );

    expect(reasons, [
      TelemetryFlushTriggers.reasonTimer,
      TelemetryFlushTriggers.reasonBackground,
      TelemetryFlushTriggers.reasonForeground,
      TelemetryFlushTriggers.reasonNetworkOnline,
      TelemetryFlushTriggers.reasonAuth,
    ]);
  });

  test('an idle app with an empty queue makes no request', () {
    triggers.timerTick(hasQueuedEvents: false);
    expect(reasons, isEmpty);
  });

  test('inactive and hidden are not flush triggers', () {
    triggers.lifecycle(AppLifecycleState.inactive);
    triggers.lifecycle(AppLifecycleState.hidden);
    triggers.lifecycle(AppLifecycleState.detached);
    expect(reasons, isEmpty);
  });

  test('going offline is not a flush; coming back online is', () {
    triggers.network(wasOffline: false, isOffline: true);
    expect(reasons, isEmpty);

    triggers.network(wasOffline: true, isOffline: false);
    expect(reasons, [TelemetryFlushTriggers.reasonNetworkOnline]);
  });

  test('staying online does not flush repeatedly', () {
    triggers.network(wasOffline: false, isOffline: false);
    expect(reasons, isEmpty);
  });

  test('sign out clears the suppression but does not flush', () {
    triggers.auth(
      event: AuthChangeEvent.signedOut,
      uid: null,
      previousUid: 'uid-1',
    );
    expect(cleared, 1);
    expect(reasons, isEmpty);
  });

  test('a token refresh for the same uid is not an auth transition', () {
    triggers.auth(
      event: AuthChangeEvent.tokenRefreshed,
      uid: 'uid-1',
      previousUid: 'uid-1',
    );
    expect(cleared, 0);
    expect(reasons, isEmpty);
  });

  test('a uid change on any event is an auth transition', () {
    triggers.auth(
      event: AuthChangeEvent.tokenRefreshed,
      uid: 'uid-2',
      previousUid: 'uid-1',
    );
    expect(cleared, 1);
    expect(reasons, [TelemetryFlushTriggers.reasonAuth]);
  });
}
