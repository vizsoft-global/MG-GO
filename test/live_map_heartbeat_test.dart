import 'package:dpd_userapp/features/duty/live_map_heartbeat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _pos({required double accuracy, double lat = 29.37}) {
  return Position(
    latitude: lat,
    longitude: 47.97,
    timestamp: DateTime(2026, 8, 13, 9),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
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
}
