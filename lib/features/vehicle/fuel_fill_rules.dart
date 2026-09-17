import 'package:flutter/services.dart';

import '../support/create_attachment.dart';

final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool stationHasLetterOrDigit(String name) {
  return _letterOrDigit.hasMatch(name.trim());
}

/// Single `.`, max 3 decimals. Blocks comma, dash, and extra dots.
String filterFuelDecimal(String raw) {
  var out = '';
  var dot = false;
  var intDigits = 0;
  var frac = 0;
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    if (ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) {
      if (!dot && intDigits < 5) {
        out += ch;
        intDigits += 1;
      } else if (dot && frac < 3) {
        out += ch;
        frac += 1;
      }
    } else if (ch == '.' && !dot && intDigits > 0) {
      out += '.';
      dot = true;
    }
  }
  return out;
}

/// Same rules as [filterFuelDecimal], but 7 integer digits so `848466` is not clipped.
String filterDistanceKm(String raw) {
  var out = '';
  var dot = false;
  var intDigits = 0;
  var frac = 0;
  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    if (ch.compareTo('0') >= 0 && ch.compareTo('9') <= 0) {
      if (!dot && intDigits < 7) {
        out += ch;
        intDigits += 1;
      } else if (dot && frac < 3) {
        out += ch;
        frac += 1;
      }
    } else if (ch == '.' && !dot && intDigits > 0) {
      out += '.';
      dot = true;
    }
  }
  return out;
}

class FuelDecimalFormatter extends TextInputFormatter {
  const FuelDecimalFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final next = filterFuelDecimal(newValue.text);
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

class DistanceKmFormatter extends TextInputFormatter {
  const DistanceKmFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final next = filterDistanceKm(newValue.text);
    return TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }
}

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
  if (!stationHasLetterOrDigit(stationName)) {
    return 'station_invalid';
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
    case 'station_invalid':
      return 'Station name must include a letter or number';
    case 'location_required':
      return 'Location is required to log fuel';
    case 'attachment_required':
      return 'Capture all required photos';
    case 'amount_required':
      return 'Enter the refund amount';
    case 'reason_required':
      return 'Enter the refund reason';
    case 'fuel_refund_attachments_required':
      return 'Please upload the required refund photos';
    default:
      return fallback;
  }
}
