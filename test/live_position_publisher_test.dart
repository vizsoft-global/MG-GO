import 'dart:convert';

import 'package:dpd_userapp/features/duty/adaptive_location_scheduler.dart';
import 'package:dpd_userapp/features/duty/live_position_publisher.dart';
import 'package:flutter_test/flutter_test.dart';

LiveFix _fix({
  TrackingStatus status = TrackingStatus.moving,
  bool replay = false,
  DateTime? clientTs,
}) {
  return LiveFix(
    latitude: 29.3759,
    longitude: 47.9774,
    trackingStatus: status,
    clientTs: clientTs ?? DateTime.utc(2026, 1, 1, 12),
    speedMps: 8.2,
    accuracyMeters: 6,
    headingDeg: 91,
    batteryPct: 74,
    isMocked: false,
    replay: replay,
  );
}

void main() {
  group('LiveCadence', () {
    const cadence = LiveCadence();
    final now = DateTime.utc(2026, 1, 1, 12);

    test('moving spacing is a fixed 5s', () {
      expect(cadence.intervalFor(TrackingStatus.moving), LiveCadence.movingInterval);
      expect(LiveCadence.movingInterval, const Duration(seconds: 5));

      expect(
        cadence.shouldPublish(
          buffered: 1,
          status: TrackingStatus.moving,
          now: now.add(const Duration(seconds: 4)),
          lastPublishAt: now,
        ),
        isFalse,
      );
      expect(
        cadence.shouldPublish(
          buffered: 1,
          status: TrackingStatus.moving,
          now: now.add(const Duration(seconds: 5)),
          lastPublishAt: now,
        ),
        isTrue,
      );
    });

    test('a stationary driver still heartbeats every 30s', () {
      expect(
        cadence.shouldPublish(
          buffered: 1,
          status: TrackingStatus.idle,
          now: now.add(const Duration(seconds: 20)),
          lastPublishAt: now,
        ),
        isFalse,
      );
      expect(
        cadence.shouldPublish(
          buffered: 1,
          status: TrackingStatus.idle,
          now: now.add(const Duration(seconds: 30)),
          lastPublishAt: now,
        ),
        isTrue,
      );
    });

    test('a full batch and a state change both jump the queue', () {
      expect(
        cadence.shouldPublish(
          buffered: LiveCadence.batchSize,
          status: TrackingStatus.moving,
          now: now.add(const Duration(seconds: 1)),
          lastPublishAt: now,
        ),
        isTrue,
      );
      expect(
        cadence.shouldPublish(
          buffered: 1,
          status: TrackingStatus.idle,
          now: now.add(const Duration(seconds: 1)),
          lastPublishAt: now,
          stateChanged: true,
        ),
        isTrue,
      );
      expect(
        cadence.shouldPublish(
          buffered: 1,
          status: TrackingStatus.deliverySubmit,
          now: now.add(const Duration(seconds: 1)),
          lastPublishAt: now,
        ),
        isTrue,
      );
    });

    test('an empty buffer never publishes, whatever else is true', () {
      expect(
        cadence.shouldPublish(
          buffered: 0,
          status: TrackingStatus.deliverySubmit,
          now: now.add(const Duration(minutes: 5)),
          lastPublishAt: null,
          stateChanged: true,
        ),
        isFalse,
      );
    });
  });

  group('LiveFix wire format', () {
    test('matches the field names the Worker reads', () {
      final json = _fix().toWireJson();
      // Names are the edge contract (`normalizePoint` in fleet-room.ts). A rename
      // here is silent data loss, not a compile error, so it is asserted.
      expect(json.keys, containsAll(<String>[
        'lat',
        'lng',
        'speed_mps',
        'accuracy_m',
        'heading_deg',
        'battery_pct',
        'tracking_status',
        'client_ts',
        'replay',
      ]));
      expect(json['tracking_status'], 'moving');
      expect(json['replay'], isFalse);
      // Must round-trip through JSON: an unencodable value would fail only at
      // runtime, on a background isolate, where nobody sees it.
      expect(jsonDecode(jsonEncode(json))['lat'], 29.3759);
    });

    test('client_ts is the capture time in UTC, not the flush time', () {
      final captured = DateTime.utc(2026, 1, 1, 9, 30, 15);
      final json = _fix(clientTs: captured).toWireJson();
      expect(json['client_ts'], '2026-01-01T09:30:15.000Z');
    });

    test('asReplay keeps the fix but marks it history-only', () {
      final original = _fix();
      final replayed = original.asReplay();
      expect(replayed.replay, isTrue);
      expect(replayed.latitude, original.latitude);
      expect(replayed.clientTs, original.clientTs);
      expect(replayed.trackingStatus, original.trackingStatus);
      expect(replayed.toWireJson()['replay'], isTrue);
    });
  });

  group('LivePositionPublisher with no LIVE_INGEST_URL', () {
    test('is inert, so the app behaves exactly as it did before the edge', () async {
      // Env.liveIngestUrl defaults to empty under `flutter test`; this is the
      // shipped-disabled path and it must never buffer, publish or throw.
      final publisher = LivePositionPublisher();
      addTearDown(publisher.dispose);

      expect(publisher.enabled, isFalse);
      publisher.add(_fix());
      expect(publisher.buffered, 0);
      expect(
        publisher.shouldPublish(
          status: TrackingStatus.moving,
          now: DateTime.utc(2026, 1, 1, 12),
        ),
        isFalse,
      );
      expect(
        await publisher.flush(
          accessToken: 'token',
          now: DateTime.utc(2026, 1, 1, 12),
        ),
        isFalse,
      );
      expect(
        await publisher.publishReplay(accessToken: 'token', fixes: [_fix()]),
        isFalse,
      );
      expect(publisher.lastSuccessAt, isNull);
    });
  });
}
