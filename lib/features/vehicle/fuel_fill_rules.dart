import '../support/create_attachment.dart';

String? fuelFillBlockReason({
  required num? litres,
  required num? costKwd,
  required String? stationName,
  required double? lat,
  required double? lng,
  required Iterable<String> kinds,
}) {
  if (litres == null || litres <= 0) return 'litres_required';
  if (costKwd == null || costKwd < 0) return 'cost_required';
  if (stationName == null || stationName.trim().isEmpty) {
    return 'station_required';
  }
  if (lat == null || lng == null) return 'location_required';
  final have = kinds.toSet();
  for (final spec in fuelFillAttachmentSpecs) {
    if (!have.contains(spec.kind)) return 'attachment_required';
  }
  return null;
}

String? fuelRefundFormBlockReason({
  required num? amount,
  required String? reason,
  required Iterable<String> kinds,
}) {
  if (amount == null || amount <= 0) return 'amount_required';
  if (reason == null || reason.trim().isEmpty) return 'reason_required';
  return missingRequiredCreateKind('fuel_refund', kinds);
}

String fleetRpcUserMessage(String code, String fallback) {
  switch (code) {
    case 'not_authenticated':
      return 'Sign in again to continue';
    case 'not_a_driver':
      return 'This account is not a driver';
    case 'driver_off_duty':
      return 'Clock in before logging fuel';
    case 'vehicle_not_assigned':
      return 'No vehicle is assigned to you';
    case 'litres_required':
      return 'Enter litres greater than 0';
    case 'cost_required':
      return 'Enter the fuel cost';
    case 'station_required':
      return 'Enter the station name';
    case 'location_required':
      return 'Location is required to log fuel';
    case 'attachment_required':
      return 'Capture all required photos';
    case 'amount_required':
      return 'Enter the refund amount';
    case 'reason_required':
      return 'Enter the refund reason';
    case 'fuel_refund_attachments_required':
      return 'Capture all four refund photos';
    default:
      return fallback;
  }
}
