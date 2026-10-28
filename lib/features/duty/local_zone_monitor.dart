import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/geo/location_sampler.dart';
import '../deliveries/delivery_proximity_service.dart';
import '../home/home_models.dart';
import '../home/home_providers.dart';
import 'duty_location_provider.dart';

/// Computes in/out-of-zone status on-device the instant the rider crosses the
/// boundary, without waiting for the next `driver_report_location` RPC.
///
/// The duty isolate still owns server pushes. This controller closes residual
/// UI lag by reading a high-accuracy GPS stream (~5 m / high accuracy) on the
/// main isolate and evaluating against the locally cached zone polygon.
///
/// The server report is still authoritative for audit / history purposes.
/// Delivery-range status still lands on [DutyLocationState.lastReport]; the
/// assigned-zone polygon (0 m buffer) is written separately so the 45-minute
/// timer cannot be cleared by a restaurant-range heartbeat.
final localZoneMonitorControllerProvider = Provider<void>((ref) {
  final controller = _LocalZoneMonitorController(ref);
  ref.onDispose(controller.dispose);
});

class _LocalZoneMonitorController {
  final _sampler = LocationSampler.instance;

  _LocalZoneMonitorController(this._ref) {
    _ref.listen<AsyncValue<HomeDashboard>>(
      homeDashboardProvider,
      (previous, next) {
        if (next.isLoading && !next.hasValue) return;
        final curr = next.asData?.value;
        if (curr == null) return;
        final isOnDuty = curr.isOnDuty;
        if (isOnDuty) {
          _ensureSubscribed();
        } else {
          _stop();
        }
      },
      fireImmediately: true,
    );

    // If the proximity geometry arrives after the first GPS sample, re-evaluate
    // against the last known position so the banner doesn't have to wait for
    // the rider to move again.
    _ref.listen<AsyncValue<dynamic>>(
      deliveryProximityContextProvider,
      (previous, next) {
        if (next.value == null) return;
        final position = _lastPosition;
        if (position != null) _evaluate(position);
      },
    );
  }

  final Ref _ref;
  StreamSubscription<Position>? _positionSub;
  bool _starting = false;
  Position? _lastPosition;

  Future<void> _ensureSubscribed() async {
    if (_positionSub != null || _starting) return;
    _starting = true;
    try {
      if (!await _sampler.isServiceEnabled()) return;
      final permission = await _sampler.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Try to emit the first read immediately so the banner doesn't wait for
      // the rider to physically move before the first evaluation runs.
      unawaited(_evaluateFromCurrentPosition());

      _positionSub = _sampler
          .positionStream(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          )
          .listen(
            _evaluate,
            onError: (_) {
              // Position errors are surfaced through the duty task handler; we
              // intentionally swallow them here so the banner just keeps
              // showing the most recent local evaluation.
            },
            cancelOnError: false,
          );
    } finally {
      _starting = false;
    }
  }

  Future<void> _evaluateFromCurrentPosition() async {
    try {
      final position = await _sampler.getCurrentPosition(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      _evaluate(position);
    } catch (_) {
      // First-position fetch failure isn't fatal — the stream will catch up.
    }
  }

  void _evaluate(Position position) {
    _lastPosition = position;

    final context = _ref.read(deliveryProximityContextProvider).value;
    if (context == null) return;

    final proximity = _ref.read(deliveryProximityServiceProvider).evaluate(
          context: context,
          latitude: position.latitude,
          longitude: position.longitude,
        );
    final unknown = proximity.reason ==
        DeliveryProximityBlockReason.contextUnavailable;
    if (!unknown) {
      final status = proximity.allowed ? 'in_zone' : 'out_of_zone';
      _ref.read(dutyLocationProvider.notifier).applyLocalZoneStatus(
            status,
            inRange: proximity.allowed,
          );
    }

    // The 45-minute window follows the same rule the server writes to
    // `driver_report_location`: inside the assigned zone **or** inside an
    // assigned store's delivery range. A store whose pin sits outside the zone
    // polygon is still where the rider works, so it must not read as "outside
    // your delivery area" and must not start or hold a checkout countdown.
    final hasAssignedZone =
        context.zoneId != null && context.zoneId!.trim().isNotEmpty;
    _ref.read(dutyLocationProvider.notifier).applyAssignedZoneStatus(
          unknown ? null : (proximity.allowed ? 'in_zone' : 'out_of_zone'),
          hasAssignedZone: hasAssignedZone,
        );
  }

  Future<void> _stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
  }

  void dispose() {
    unawaited(_stop());
  }
}
