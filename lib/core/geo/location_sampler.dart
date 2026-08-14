import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

/// Single entry point for reading GPS from the device (Geolocator).
///
/// Use [DeviceLocationResolver] when the UI needs permission prompts, caching,
/// and mock-location integrity checks (pickup/finish/proximity preview).
/// Use this class directly from background isolates and lightweight monitors
/// that must not depend on Supabase or security UI.
class LocationSampler {
  LocationSampler._();

  static final LocationSampler instance = LocationSampler._();

  static const lastKnownMaxAge = Duration(minutes: 3);

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  Future<Position> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 8),
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeLimit,
      ),
    );
  }

  /// Returns last-known fix when fresh enough; otherwise null.
  Future<Position?> lastKnownIfFresh({
    Duration maxAge = lastKnownMaxAge,
    DateTime? now,
    double maxAccuracyMeters = 80,
  }) async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    final clock = now ?? DateTime.now();
    if (clock.difference(position.timestamp) > maxAge) return null;
    // Reject coarse last-known fixes so fleet pins don't jump on bad cache.
    if (position.accuracy > maxAccuracyMeters) return null;
    return position;
  }

  /// Best effort: use a fresh accurate cache, otherwise a fresh high-accuracy
  /// fix. Prefer accurate GPS over a stale low-accuracy reading.
  Future<Position> getBestPosition({
    Duration lastKnownMaxAge = const Duration(seconds: 12),
    Duration timeLimit = const Duration(seconds: 12),
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final lastKnown = await lastKnownIfFresh(maxAge: lastKnownMaxAge);
    if (lastKnown != null) return lastKnown;
    return getCurrentPosition(accuracy: accuracy, timeLimit: timeLimit);
  }

  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 5,
    Duration? intervalDuration,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: _streamSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: intervalDuration,
      ),
    );
  }

  /// Plain [LocationSettings] has no way to ask for a *rate* — it only filters by
  /// distance, so a rider stopped at a light emits nothing and a fast one emits
  /// as often as the provider feels like. [AndroidSettings.intervalDuration] is
  /// the only knob that pins the cadence the admin interpolator is built around.
  LocationSettings _streamSettings({
    required LocationAccuracy accuracy,
    required int distanceFilter,
    Duration? intervalDuration,
  }) {
    if (intervalDuration == null) {
      return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    }
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: intervalDuration,
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }
}
