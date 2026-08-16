import 'package:dpd_userapp/features/duty/adaptive_location_scheduler.dart';
import 'package:dpd_userapp/features/duty/live_map_heartbeat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _pos({required double accuracy, double lat = 29.37, double speed = 0}) {
  return Position(
    latitude: lat,
    longitude: 47.97,
    timestamp: DateTime(2026, 8, 13, 9),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}

void main() {
  test('coarse GPS still heartbeats the last good pin so the live map keeps the driver', () {
    final lastGood = _pos(accuracy: 12, lat: 29.38);
    final coarse = _pos(accuracy: 180, lat: 29.90);
    expect(
      heartbeatPosition(
        current: coarse,
        lastGood: lastGood,
        force: false,
        needsInitialReport: false,
      ),
      lastGood,
    );
  });

  test('first on-duty sample and forced ticks still send the current fix', () {
    final coarse = _pos(accuracy: 180);
    expect(
      heartbeatPosition(
        current: coarse,
        lastGood: null,
        force: false,
        needsInitialReport: true,
      ),
      coarse,
    );
  });

  test('no last-good coarse ping is skipped (nothing to pin)', () {
    expect(
      heartbeatPosition(
        current: _pos(accuracy: 180),
        lastGood: null,
        force: false,
        needsInitialReport: false,
      ),
      isNull,
    );
  });

  test('moving coarse GPS follows the live fix so the admin pin travels', () {
    final lastGood = _pos(accuracy: 12, speed: 0);
    final live = _pos(accuracy: 180, speed: 8, lat: 29.90);
    expect(
      heartbeatPosition(
        current: live,
        lastGood: lastGood,
        force: false,
        needsInitialReport: false,
      ),
      live,
    );
  });

  test('a network-provider fix at exactly 100m does not move the pin', () {
    // The old threshold *was* 100, so Android's network provider — which reports
    // exactly 100 from a tower that can be 600m away — passed the gate. That hop is
    // what inflated the day's distance and drew the jitter smudge on the admin map.
    final lastGood = _pos(accuracy: 12, lat: 29.38);
    final tower = _pos(accuracy: 100, lat: 29.90);
    expect(
      heartbeatPosition(
        current: tower,
        lastGood: lastGood,
        force: false,
        needsInitialReport: false,
      ),
      lastGood,
    );
  });

  test('a forced tick does not promote a coarse fix over a warm accurate one', () {
    final lastGood = _pos(accuracy: 12, lat: 29.38);
    final coarse = _pos(accuracy: 180, lat: 29.90);
    expect(
      heartbeatPosition(
        current: coarse,
        lastGood: lastGood,
        force: true,
        needsInitialReport: false,
      ),
      lastGood,
    );
  });

  test('an accurate fix that has aged out yields to the coarse one', () {
    final stale = Position(
      latitude: 29.38,
      longitude: 47.97,
      timestamp: DateTime(2026, 8, 13, 8, 50),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    final coarse = _pos(accuracy: 180, lat: 29.40);
    expect(
      heartbeatPosition(
        current: coarse,
        lastGood: stale,
        force: false,
        needsInitialReport: false,
      ),
      coarse,
    );
  });

  test('a 45m urban-canyon fix is still accepted as the live pin', () {
    final urban = _pos(accuracy: 45, lat: 29.40);
    expect(
      heartbeatPosition(
        current: urban,
        lastGood: _pos(accuracy: 12, lat: 29.38),
        force: false,
        needsInitialReport: false,
      ),
      urban,
    );
  });

  test('motion uses live displacement even when GPS speed is 0', () {
    final scheduler = AdaptiveLocationScheduler();
    final lastGood = _pos(accuracy: 12, speed: 0, lat: 29.38);
    final live = _pos(accuracy: 180, speed: 0, lat: 29.90);
    scheduler.updateFromPosition(lastGood, DateTime(2026, 8, 13, 9));
    applyLiveMotion(
      scheduler,
      liveFix: live,
      now: DateTime(2026, 8, 13, 9, 0, 5),
    );
    expect(scheduler.status, TrackingStatus.moving);
  });
}
