import 'dart:convert';

import 'package:dpd_userapp/core/config/env.dart';
import 'package:dpd_userapp/features/duty/adaptive_location_scheduler.dart';
import 'package:dpd_userapp/features/duty/live_position_publisher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

LiveFix _fix({
  TrackingStatus status = TrackingStatus.moving,
  bool replay = false,
  DateTime? clientTs,
  String? headingSource = 'gps',
}) {
  return LiveFix(
    latitude: 29.3759,
    longitude: 47.9774,
    trackingStatus: status,
    clientTs: clientTs ?? DateTime.utc(2026, 1, 1, 12),
    speedMps: 8.2,
    accuracyMeters: 6,
    headingDeg: 91,
    headingSource: headingSource,
    compassDeg: 88,
    batteryPct: 74,
    isMocked: false,
    replay: replay,
  );
}

void main() {
  group('LiveCadence', () {
    const cadence = LiveCadence();
    final now = DateTime.utc(2026, 1, 1, 12);

    test('moving spacing is a fixed 1s', () {
      expect(cadence.intervalFor(TrackingStatus.moving), LiveCadence.movingInterval);
      expect(LiveCadence.movingInterval, const Duration(seconds: 1));
    });

    test('a single moving fix waits up to 2s for a batch partner', () {
      // The gate is the buffer deadline, not the fix interval: publishing at 1s
      // would send one fix per request and give up batching entirely.
      expect(
        cadence.shouldPublish(
          buffered: 1,
          status: TrackingStatus.moving,
          now: now.add(const Duration(milliseconds: 1500)),
          lastPublishAt: now,
        ),
        isFalse,
      );
      expect(
        cadence.shouldPublish(
          buffered: 1,
          status: TrackingStatus.moving,
          now: now.add(LiveCadence.maxBufferHold),
          lastPublishAt: now,
        ),
        isTrue,
      );
    });

    test('two fixes at 1Hz publish as one batch', () {
      expect(LiveCadence.batchSize, 2);
      expect(
        cadence.shouldPublish(
          buffered: 2,
          status: TrackingStatus.moving,
          now: now.add(const Duration(seconds: 1)),
          lastPublishAt: now,
        ),
        isTrue,
        reason: '~2s of movement per request rather than one request per second',
      );
    });

    test('idle stays at 30s even though moving went to 1Hz', () {
      // A parked phone at 1Hz is the same coordinate 30 times over, and each one
      // costs a Durable Object turn.
      expect(LiveCadence.idleInterval, const Duration(seconds: 30));
      expect(cadence.flushDeadlineFor(TrackingStatus.idle), LiveCadence.idleInterval);
    });

    test('idle does not publish just because two fixes are buffered', () {
      expect(
        cadence.shouldPublish(
          buffered: 2,
          status: TrackingStatus.idle,
          now: now.add(const Duration(seconds: 2)),
          lastPublishAt: now,
        ),
        isFalse,
        reason: 'batchSize is moving-only; idle waits for the 30s deadline',
      );
      expect(
        cadence.shouldPublish(
          buffered: 2,
          status: TrackingStatus.idle,
          now: now.add(LiveCadence.idleInterval),
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

    test('edge fallback is forced only for state changes and delivery_submit', () {
      expect(
        edgeDurableFallback(
          stateChanged: false,
          status: TrackingStatus.moving,
          now: now.add(const Duration(seconds: 2)),
          lastFallbackAt: now,
        ),
        EdgeDurableFallback.skip,
      );
      expect(
        edgeDurableFallback(
          stateChanged: false,
          status: TrackingStatus.moving,
          now: now.add(kWatchdogFallbackGap),
          lastFallbackAt: now,
        ),
        EdgeDurableFallback.report,
      );
      expect(
        edgeDurableFallback(
          stateChanged: false,
          status: TrackingStatus.idle,
          now: now.add(const Duration(seconds: 15)),
          lastFallbackAt: now,
        ),
        EdgeDurableFallback.skip,
      );
      expect(
        edgeDurableFallback(
          stateChanged: false,
          status: TrackingStatus.idle,
          now: now.add(LiveCadence.idleInterval),
          lastFallbackAt: now,
        ),
        EdgeDurableFallback.report,
      );
      expect(
        edgeDurableFallback(
          stateChanged: true,
          status: TrackingStatus.moving,
          now: now.add(const Duration(seconds: 1)),
          lastFallbackAt: now,
        ),
        EdgeDurableFallback.force,
      );
      expect(
        edgeDurableFallback(
          stateChanged: false,
          status: TrackingStatus.deliverySubmit,
          now: now.add(const Duration(seconds: 1)),
          lastFallbackAt: now,
        ),
        EdgeDurableFallback.force,
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
      // Additive since fusion. The Worker reads a missing `heading_source` as
      // `gps`, so older builds keep rotating their marker.
      expect(json.keys, containsAll(<String>['heading_source', 'compass_deg']));
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

    test('asReplay carries the heading source, which asReplay could silently drop', () {
      final replayed = _fix(headingSource: 'compass').asReplay();
      expect(replayed.headingSource, 'compass');
      expect(replayed.toWireJson()['heading_source'], 'compass');
    });
  });

  group('Env.liveIngestUrl', () {
    test('defaults to the production edge when the build never mentions it', () {
      // The old default was `''`, so a release built without
      // `--dart-define-from-file=env/prod.json` shipped with the live rail off and
      // nothing to show it: every other backend URL has a prod default, so the app
      // worked, and the admin map quietly ran on minute-old database reads.
      expect(Env.liveIngestUrl, Env.prodLiveIngestUrl);
      expect(Env.isLiveIngestEnabled, isTrue);
      expect(Env.liveIngestEndpoint, '${Env.prodLiveIngestUrl}/ingest');
    });
  });

  group('LivePositionPublisher with the rail switched off', () {
    test('is inert, so the app behaves exactly as it did before the edge', () async {
      // The kill switch is now an explicitly empty `LIVE_INGEST_URL`. Injected here
      // rather than inferred from the build, so this path stays covered on a build
      // where the rail is on.
      final publisher = LivePositionPublisher(enabled: false);
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

  group('LivePositionPublisher with the rail on', () {
    test('posts the batch to /ingest as the driver, not anonymously', () async {
      // The room resolves the driver from this header alone and answers 401 when it
      // cannot (`resolveDriverId` in fleet-room.ts). A production build did exactly
      // that once and then never published again, so the shape of the request is
      // asserted rather than assumed.
      http.Request? sent;
      final publisher = LivePositionPublisher(
        enabled: true,
        endpoint: 'https://edge.test/ingest',
        client: MockClient((request) async {
          sent = request;
          return http.Response('{"ok":true,"accepted":2}', 200);
        }),
      );
      addTearDown(publisher.dispose);

      publisher.add(_fix());
      publisher.add(_fix());
      final ok = await publisher.flush(
        accessToken: 'driver-jwt',
        now: DateTime.utc(2026, 1, 1, 12),
        dutyStateVersion: 7,
      );

      expect(ok, isTrue);
      expect(sent, isNotNull);
      expect(sent!.url.toString(), 'https://edge.test/ingest');
      expect(sent!.headers['Authorization'], 'Bearer driver-jwt');
      final body = jsonDecode(sent!.body) as Map<String, dynamic>;
      expect((body['points'] as List).length, 2);
      // Without this the room cannot tell this session from a foreground service that
      // outlived a clock-out, which is what `409 stale_duty_state` exists to refuse.
      expect(body['duty_state_version'], 7);
      expect(publisher.buffered, 0);
    });

    test('a rejected batch is dropped so the durable path owns the fix', () async {
      final publisher = LivePositionPublisher(
        enabled: true,
        endpoint: 'https://edge.test/ingest',
        client: MockClient(
          (_) async => http.Response('{"ok":false,"error":"unauthorized"}', 401),
        ),
      );
      addTearDown(publisher.dispose);

      publisher.add(_fix());
      final ok = await publisher.flush(
        accessToken: 'expired-jwt',
        now: DateTime.utc(2026, 1, 1, 12),
      );

      expect(ok, isFalse, reason: 'caller falls back to driver_report_location');
      expect(publisher.buffered, 0, reason: 'stale coordinates must not be re-sent');
      expect(publisher.lastSuccessAt, isNull);
    });
  });
}
