import 'package:dpd_userapp/core/telemetry/telemetry_event.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_event_types.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_queue_policy.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_service.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_store.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRpc {
  FakeRpc({this.response});

  final Object? Function(List<Map<String, Object?>>)? response;
  final List<List<Map<String, Object?>>> calls = [];
  bool offline = false;

  Future<Object?> call(List<Map<String, Object?>> events) async {
    if (offline) throw Exception('SocketException');
    calls.add(events);
    if (response != null) return response!(events);
    return {
      'ok': true,
      'accepted': events.length,
      'duplicates': 0,
      'rejected': 0,
    };
  }
}

TelemetryService buildService({
  required InMemoryTelemetryStore store,
  required FakeRpc rpc,
  String? Function()? uid,
  DateTime Function()? clock,
}) {
  var counter = 0;
  return TelemetryService(
    store: store,
    rpc: rpc.call,
    uid: uid ?? () => 'driver-uid',
    clock: clock,
    sessionId: 'session-1',
    idFactory: () => 'event-${counter++}',
  );
}

void main() {
  test('an event is queued with no network call', () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc();
    final service = buildService(store: store, rpc: rpc);

    await service.record(
      TelemetryEvents.screenOpen,
      context: {'screen': 'home'},
    );

    expect(store.rows, hasLength(1));
    expect(rpc.calls, isEmpty);
  });

  test('depth 25 triggers a flush, 24 does not', () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc();
    final service = buildService(store: store, rpc: rpc);

    for (var i = 0; i < kTelemetryFlushDepthThreshold - 1; i++) {
      await service.record(
        TelemetryEvents.screenOpen,
        context: {'screen': 'home'},
      );
    }
    expect(rpc.calls, isEmpty);

    await service.record(
      TelemetryEvents.screenOpen,
      context: {'screen': 'home'},
    );
    await Future<void>.delayed(Duration.zero);

    expect(rpc.calls, hasLength(1));
    expect(rpc.calls.first, hasLength(kTelemetryFlushDepthThreshold));
    expect(store.rows, isEmpty);
  });

  test('a burst is sent in batches of at most 100, never one call per event',
      () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc();
    final start = DateTime.utc(2026, 8, 13, 9);
    final service = buildService(
      store: store,
      rpc: rpc,
      clock: () => start.add(const Duration(minutes: 10)),
    );

    for (var i = 0; i < 250; i++) {
      await store.insert(_event('burst-$i', start.add(Duration(seconds: i))));
    }

    await service.flush(reason: 'test');

    expect(rpc.calls, hasLength(3));
    expect(rpc.calls[0], hasLength(kTelemetryMaxBatchSize));
    expect(rpc.calls[1], hasLength(kTelemetryMaxBatchSize));
    expect(rpc.calls[2], hasLength(50));
    expect(store.rows, isEmpty);
  });

  test('the payload carries no driver_id and no forbidden fields', () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc();
    final service = buildService(store: store, rpc: rpc);

    await service.record(
      TelemetryEvents.actionTap,
      context: {'action': 'duty_on', 'screen': 'home', 'result': 'ok'},
    );
    await service.flush(reason: 'test');

    final payload = rpc.calls.single.single;
    expect(payload.containsKey('driver_id'), isFalse);
    expect(payload['event_name'], TelemetryEvents.actionTap);
    expect(payload['session_id'], 'session-1');
    expect(payload['event_id'], isNotNull);
    expect(payload['client_ts'], isA<String>());
    expect(payload['context'], {
      'action': 'duty_on',
      'screen': 'home',
      'result': 'ok',
    });
  });

  test('offline keeps the queue, reconnect flushes the same event_id',
      () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc()..offline = true;
    final service = buildService(store: store, rpc: rpc);

    await service.record(
      TelemetryEvents.networkOffline,
      context: {'network_state': 'none'},
    );
    await service.flush(reason: 'test', force: true);

    expect(rpc.calls, isEmpty);
    expect(store.rows, hasLength(1));
    final queuedId = store.rows.single.eventId;

    rpc.offline = false;
    await service.flush(reason: 'network_online', force: true);

    expect(rpc.calls, hasLength(1));
    expect(rpc.calls.single.single['event_id'], queuedId);
    expect(store.rows, isEmpty);
  });

  test('client_ts is stamped at enqueue, not at flush', () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc();
    var now = DateTime.utc(2026, 8, 13, 9, 5);
    final service = buildService(
      store: store,
      rpc: rpc,
      clock: () => now,
    );

    await service.record(
      TelemetryEvents.appBackground,
      context: {'screen': 'home'},
    );
    now = DateTime.utc(2026, 8, 13, 9, 45);
    await service.flush(reason: 'test');

    expect(
      rpc.calls.single.single['client_ts'],
      DateTime.utc(2026, 8, 13, 9, 5).toIso8601String(),
    );
  });

  test('throttled clears the batch and opens a cooldown', () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc(
      response: (_) => {'ok': true, 'throttled': true, 'accepted': 0},
    );
    final now = DateTime.utc(2026, 8, 13, 9);
    final service = buildService(store: store, rpc: rpc, clock: () => now);

    await service.record(
      TelemetryEvents.screenOpen,
      context: {'screen': 'home'},
    );
    await service.flush(reason: 'test');

    expect(store.rows, isEmpty);
    expect(service.cooldownUntil, now.add(kTelemetryThrottleCooldown));

    await service.record(
      TelemetryEvents.screenOpen,
      context: {'screen': 'deliveries'},
    );
    await service.flush(reason: 'test');
    expect(rpc.calls, hasLength(1), reason: 'cooldown must suppress the retry');
  });

  test('rejected events are removed rather than retried forever', () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc(
      response: (events) => {
        'ok': true,
        'accepted': 0,
        'rejected': events.length,
        'rejects': [
          for (final e in events)
            {'event_id': e['event_id'], 'reason': 'unknown_event'},
        ],
      },
    );
    final service = buildService(store: store, rpc: rpc);

    await service.record(
      TelemetryEvents.screenOpen,
      context: {'screen': 'home'},
    );
    await service.flush(reason: 'test');

    expect(store.rows, isEmpty);
    expect(rpc.calls, hasLength(1));
  });

  test('an unknown event name never reaches the queue', () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc();
    final service = buildService(store: store, rpc: rpc);

    await service.record('gps.ping', context: {'lat': 29.3});

    expect(store.rows, isEmpty);
  });

  test('a signed-out app queues but does not call the RPC', () async {
    final store = InMemoryTelemetryStore();
    final rpc = FakeRpc();
    final service = buildService(store: store, rpc: rpc, uid: () => null);

    await service.record(
      TelemetryEvents.appStartup,
      context: {'cold_start': true},
    );
    await service.flush(reason: 'test', force: true);

    expect(store.rows, hasLength(1));
    expect(rpc.calls, isEmpty);
  });
}

/// Pre-seeds the queue directly, which is how a burst that accumulated while
/// offline looks by the time a flush runs.
TelemetryEvent _event(String id, DateTime ts) => TelemetryEvent(
      eventId: id,
      eventName: TelemetryEvents.screenOpen,
      category: 'screen',
      clientTs: ts,
      sessionId: 'session-1',
      userId: 'driver-uid',
      context: const {'screen': 'home'},
    );
