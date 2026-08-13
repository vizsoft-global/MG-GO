import 'package:dpd_userapp/core/telemetry/telemetry_event_types.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_queue_policy.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_service.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the queue never exceeds 2000 rows and drops the oldest', () async {
    final store = InMemoryTelemetryStore();
    var counter = 0;
    var tick = DateTime.utc(2026, 8, 13, 9);

    final service = TelemetryService(
      store: store,
      uid: () => null, // no session: nothing flushes, so only the cap acts
      sessionId: 'session-1',
      idFactory: () => 'event-${counter++}',
      clock: () {
        tick = tick.add(const Duration(milliseconds: 10));
        return tick;
      },
      rpc: (_) async => {'ok': true, 'accepted': 0},
    );

    for (var i = 0; i < kTelemetryMaxQueueRows + 30; i++) {
      await service.record(
        TelemetryEvents.screenOpen,
        context: {'screen': 'home'},
      );
    }

    expect(store.rows, hasLength(kTelemetryMaxQueueRows));
    // The oldest 30 are gone; the newest survived.
    expect(store.rows.any((r) => r.eventId == 'event-0'), isFalse);
    expect(store.rows.any((r) => r.eventId == 'event-2029'), isTrue);
  });

  test('overflow emits at most one queue.created per flush, with no recursion',
      () async {
    final store = InMemoryTelemetryStore();
    var counter = 0;
    var tick = DateTime.utc(2026, 8, 13, 9);
    final sent = <Map<String, Object?>>[];
    // Signed out while the burst accumulates, so the growth phase is pure
    // enqueue-and-trim; the explicit flushes below are the cycles under test.
    String? uid;

    final service = TelemetryService(
      store: store,
      uid: () => uid,
      sessionId: 'session-1',
      idFactory: () => 'event-${counter++}',
      clock: () {
        tick = tick.add(const Duration(milliseconds: 10));
        return tick;
      },
      // Reject everything so the queue keeps growing: if the overflow notice
      // could feed itself, this is where it would run away.
      rpc: (events) async {
        sent.addAll(events);
        return {'ok': false, 'error': 'not_authenticated'};
      },
    );

    for (var i = 0; i < kTelemetryMaxQueueRows + 60; i++) {
      await service.record(
        TelemetryEvents.screenOpen,
        context: {'screen': 'home'},
      );
    }

    expect(store.rows, hasLength(kTelemetryMaxQueueRows));

    uid = 'driver-uid';
    await service.flush(reason: 'test', force: true);
    final noticesAfterFirstFlush = store.rows
        .where((r) => r.eventName == TelemetryEvents.queueCreated)
        .toList();
    expect(noticesAfterFirstFlush, hasLength(1));
    expect(noticesAfterFirstFlush.single.context['queue'], 'telemetry');
    expect(noticesAfterFirstFlush.single.context['reason'], 'overflow');
    expect(noticesAfterFirstFlush.single.context['dropped'], greaterThan(0));

    // A second flush with nothing newly dropped writes no further notice.
    await service.flush(reason: 'test', force: true);
    expect(
      store.rows
          .where((r) => r.eventName == TelemetryEvents.queueCreated)
          .length,
      1,
    );
    expect(store.rows, hasLength(kTelemetryMaxQueueRows));
  });
}
