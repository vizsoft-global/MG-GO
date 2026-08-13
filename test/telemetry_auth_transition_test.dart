import 'package:dpd_userapp/core/telemetry/telemetry_event.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_event_types.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_service.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('not_a_driver suppresses flushing for that uid only, and temporarily',
      () async {
    final store = InMemoryTelemetryStore();
    var uid = 'uid-not-a-driver';
    var calls = 0;
    var counter = 0;

    final service = TelemetryService(
      store: store,
      uid: () => uid,
      sessionId: 'session-1',
      idFactory: () => 'event-${counter++}',
      rpc: (events) async {
        calls++;
        if (uid == 'uid-not-a-driver') {
          return {'ok': false, 'error': 'not_a_driver'};
        }
        return {'ok': true, 'accepted': events.length};
      },
    );

    await service.record(
      TelemetryEvents.appStartup,
      context: {'cold_start': true},
    );
    await service.flush(reason: 'test');

    expect(calls, 1);
    expect(service.suppressedUid, 'uid-not-a-driver');
    expect(store.rows, isEmpty, reason: 'the rejected batch is dropped');

    // Same uid: suppressed, no further calls however many times we flush.
    await service.record(
      TelemetryEvents.screenOpen,
      context: {'screen': 'home'},
    );
    await service.flush(reason: 'test', force: true);
    await service.flush(reason: 'test', force: true);
    expect(calls, 1);

    // A real auth transition clears it — the suppression is never permanent.
    // The event queued under the old uid is purged rather than misfiled, so a
    // fresh one is what proves flushing resumed.
    uid = 'uid-real-driver';
    service.clearAuthSuppression();
    await service.record(
      TelemetryEvents.screenOpen,
      context: {'screen': 'home'},
    );
    await service.flush(reason: 'auth', force: true);

    expect(service.suppressedUid, isNull);
    expect(calls, 2);
    expect(store.rows, isEmpty);
  });

  test('a different uid is not suppressed even before an explicit clear',
      () async {
    final store = InMemoryTelemetryStore();
    var uid = 'uid-a';
    var calls = 0;
    var counter = 0;

    final service = TelemetryService(
      store: store,
      uid: () => uid,
      sessionId: 'session-1',
      idFactory: () => 'event-${counter++}',
      rpc: (events) async {
        calls++;
        if (uid == 'uid-a') return {'ok': false, 'error': 'not_a_driver'};
        return {'ok': true, 'accepted': events.length};
      },
    );

    await service.record(TelemetryEvents.appStartup, context: {'cold_start': true});
    await service.flush(reason: 'test');
    expect(service.suppressedUid, 'uid-a');

    uid = 'uid-b';
    await service.record(TelemetryEvents.screenOpen, context: {'screen': 'home'});
    await service.flush(reason: 'test', force: true);

    expect(calls, 2, reason: 'suppression is scoped to the uid that caused it');
  });

  test('pre-login events are adopted by the driver who signs in', () async {
    final store = InMemoryTelemetryStore();
    String? uid;
    final sent = <Map<String, Object?>>[];
    var counter = 0;

    final service = TelemetryService(
      store: store,
      uid: () => uid,
      sessionId: 'session-1',
      idFactory: () => 'event-${counter++}',
      rpc: (events) async {
        sent.addAll(events);
        return {'ok': true, 'accepted': events.length};
      },
    );

    await service.record(
      TelemetryEvents.appStartup,
      context: {'cold_start': true},
    );
    await service.flush(reason: 'test', force: true);
    expect(sent, isEmpty);
    expect(store.rows.single.userId, isNull);

    uid = 'uid-after-login';
    await service.flush(reason: 'auth', force: true);

    expect(sent, hasLength(1));
    expect(sent.single['event_name'], TelemetryEvents.appStartup);
  });

  test("another driver's queued rows are purged instead of misfiled", () async {
    final store = InMemoryTelemetryStore();
    await store.insert(TelemetryEvent(
      eventId: 'old-driver-event',
      eventName: TelemetryEvents.screenOpen,
      category: 'screen',
      clientTs: DateTime.now(),
      userId: 'uid-previous',
      context: const {'screen': 'home'},
    ));

    final sent = <Map<String, Object?>>[];
    final service = TelemetryService(
      store: store,
      uid: () => 'uid-current',
      sessionId: 'session-1',
      idFactory: () => 'event-new',
      rpc: (events) async {
        sent.addAll(events);
        return {'ok': true, 'accepted': events.length};
      },
    );

    await service.flush(reason: 'auth', force: true);

    expect(sent, isEmpty);
    expect(store.rows, isEmpty);
  });
}
