import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo/zone_geometry.dart';
import '../../l10n/app_localizations.dart';
import '../auth/driver_access_monitor.dart';
import '../auth/rider_auth_service.dart';
import 'delivery_proximity_service.dart';
import 'delivery_service.dart';

/// Side effects for delivery errors (e.g. device session revoked).
Future<bool> handleDeliveryServiceExceptionActions(
  DeliveryServiceException error,
  WidgetRef ref,
) async {
  if (error.code == 'driver_blocked' || error.code == 'driver_archived') {
    await ref.read(driverAccessEnforcerProvider).enforce(
          reason: error.code == 'driver_archived'
              ? 'driver_archived'
              : (error.message.isNotEmpty ? error.message : null),
        );
    return true;
  }
  if (error.code == 'device_revoked') {
    await ref.read(riderAuthServiceProvider).signOut(keepRememberMe: true);
    return true;
  }
  return false;
}

String messageForDeliveryServiceException(
  DeliveryServiceException error,
  AppLocalizations l10n,
) {
  return switch (error.code) {
    'order_id_required' => l10n.orderIdRequired,
    'invalid_order_id' => l10n.invalidOrderId,
    'auth' => l10n.pleaseSignInAgain,
    'inactive' => l10n.accountNotActive,
    'driver_blocked' => error.message.isNotEmpty
        ? error.message
        : l10n.accountBlockedDefault,
    'driver_archived' => l10n.authDriverArchived,
    'delivery_out_of_range' => l10n.outsideAllowedDeliveryArea,
    'driver_off_duty' => l10n.mustBeOnDutyToAddDelivery,
    'location_required' => l10n.gpsRequiredForDelivery,
    'proximity_context_unavailable' => l10n.couldNotLoadDeliveryLocationRules,
    'active_pickup_exists' => l10n.activePickupExists,
    'cancel_reason_required' => l10n.cancelReasonRequired,
    'duplicate_order_id' => l10n.duplicateOrderId,
    'device_revoked' => l10n.signedInOnAnotherDeviceToast,
    _ => error.message.isNotEmpty ? error.message : l10n.somethingWentWrong,
  };
}

String? messageForProximityStatus(
  DeliveryProximityStatus status,
  AppLocalizations l10n,
) {
  if (status.allowed) return null;

  switch (status.reason) {
    case DeliveryProximityBlockReason.contextUnavailable:
      return status.zoneTarget
          ? l10n.zoneNotConfigured
          : l10n.noRestaurantsAssigned;
    case DeliveryProximityBlockReason.outOfRange:
      final range = formatDistanceMeters(status.proximityMeters.toDouble());
      final target = status.zoneTarget ? l10n.yourZone : l10n.assignedRestaurant;
      final beyond = status.distanceBeyondRangeMeters;
      if (beyond == null || !beyond.isFinite || beyond <= 0) {
        return l10n.moveWithinRangeToLog(range, target);
      }
      return l10n.outsideRangeDetails(
        formatDistanceMeters(beyond),
        range,
        target,
      );
    case DeliveryProximityBlockReason.locationUnavailable:
      return l10n.gpsRequiredForDelivery;
    case DeliveryProximityBlockReason.none:
    case DeliveryProximityBlockReason.inRange:
    case DeliveryProximityBlockReason.proximityDisabled:
      return null;
  }
}

String messageForProximityContextError(String rawMessage, AppLocalizations l10n) {
  final msg = rawMessage.toLowerCase();
  if (msg.contains('not_authenticated')) {
    return l10n.sessionExpired;
  }
  if (msg.contains('not_a_driver')) {
    return l10n.accountNotSetupAsDriver;
  }
  if (msg.contains('could not find the function')) {
    return l10n.serverUpdateRequired;
  }
  return l10n.couldNotLoadDeliveryLocationRules;
}
