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
    LocationAccuracy accuracy = LocationAccuracy.medium,
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
  }) async {
    final position = await Geolocator.getLastKnownPosition();
    if (position == null) return null;
    final clock = now ?? DateTime.now();
    if (clock.difference(position.timestamp) > maxAge) return null;
    return position;
  }

  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.medium,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
