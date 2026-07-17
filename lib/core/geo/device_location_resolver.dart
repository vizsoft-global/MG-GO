import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/deliveries/delivery_service.dart';
import '../security/integrity_checker.dart';
import '../security/screen_protector_service.dart';
import '../security/security_event_repository.dart';
import 'location_sampler.dart';

/// Resolves GPS for delivery flows: permission prompts, short-lived cache,
/// mock-location checks, then fresh high-accuracy reads on submit.
class DeviceLocationResolver {
  DeviceLocationResolver._();
  static final DeviceLocationResolver instance = DeviceLocationResolver._();
  static final IntegrityChecker _integrity = IntegrityChecker(
    repository: SecurityEventRepository(Supabase.instance.client),
    screenProtectorService: ScreenProtectorService(),
  );

  static const _memoryMaxAge = Duration(seconds: 45);

  final LocationSampler _sampler = LocationSampler.instance;

  Position? _memoryPosition;
  DateTime? _memoryAt;

  void remember(Position position) {
    _memoryPosition = position;
    _memoryAt = DateTime.now();
  }

  void clear() {
    _memoryPosition = null;
    _memoryAt = null;
  }

  Future<Position> resolve({
    bool highAccuracy = false,
    bool requestIfDenied = true,
  }) async {
    await _ensurePermission(requestIfDenied: requestIfDenied);

    final now = DateTime.now();
    final cached = _memoryPosition;
    if (cached != null &&
        _memoryAt != null &&
        now.difference(_memoryAt!) <= _memoryMaxAge) {
      if (!highAccuracy) return cached;
    }

    final lastKnown = await _sampler.lastKnownIfFresh(now: now);
    if (lastKnown != null) {
      try {
        await _integrity.assertTrustedPosition(
          lastKnown,
          action: 'delivery_location_resolve_last_known',
        );
      } on SecurityBlockedException catch (e) {
        throw DeliveryServiceException(
          e.message,
          code: 'mock_location_detected',
        );
      }
      remember(lastKnown);
      if (!highAccuracy) return lastKnown;
    }

    final position = await _sampler.getCurrentPosition(
      accuracy: highAccuracy
          ? LocationAccuracy.high
          : LocationAccuracy.medium,
      timeLimit: Duration(seconds: highAccuracy ? 20 : 8),
    );
    try {
      await _integrity.assertTrustedPosition(
        position,
        action: 'delivery_location_resolve_current',
      );
    } on SecurityBlockedException catch (e) {
      throw DeliveryServiceException(e.message, code: 'mock_location_detected');
    }
    remember(position);
    return position;
  }

  Future<void> _ensurePermission({bool requestIfDenied = true}) async {
    final enabled = await _sampler.isServiceEnabled();
    if (!enabled) {
      throw DeliveryServiceException(
        'Turn on location services to log a delivery',
      );
    }

    var permission = await _sampler.checkPermission();
    if (permission == LocationPermission.denied && requestIfDenied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw DeliveryServiceException(
        'Location permission is required to log a delivery',
      );
    }
  }
}
