import '../../l10n/app_localizations.dart';
import 'order_id.dart';

/// Known cancel reason codes stored in `deliveries.cancel_reason`.
enum CancelReason {
  itemUnavailable('item_unavailable'),
  restaurantCanceled('restaurant_canceled'),
  longPreparation('long_preparation'),
  highwayOrder('highway_order'),
  autoAcceptUnconfirmed('auto_accept_unconfirmed'),
  customerCanceled('customer_canceled'),
  foodTheft('food_theft'),
  navigationIssue('navigation_issue'),
  deliveryDelayed('delivery_delayed'),
  foodTooLarge('food_too_large'),
  merchantClosed('merchant_closed'),
  orderReassigned('order_reassigned'),
  accident('accident'),
  wrongAddress('wrong_address'),
  vehicleBreakdown('vehicle_breakdown'),
  customerNoShow('customer_no_show'),
  customerRefused('customer_refused'),
  restaurantIssue('restaurant_issue'),
  other('other');

  const CancelReason(this.apiValue);

  final String apiValue;

  String label(AppLocalizations l10n) => switch (this) {
    CancelReason.itemUnavailable => l10n.cancelReasonItemUnavailable,
    CancelReason.restaurantCanceled => l10n.cancelReasonRestaurantCanceled,
    CancelReason.longPreparation => l10n.cancelReasonLongPreparation,
    CancelReason.highwayOrder => l10n.cancelReasonHighwayOrder,
    CancelReason.autoAcceptUnconfirmed => l10n.cancelReasonAutoAcceptUnconfirmed,
    CancelReason.customerCanceled => l10n.cancelReasonCustomerCanceled,
    CancelReason.foodTheft => l10n.cancelReasonFoodTheft,
    CancelReason.navigationIssue => l10n.cancelReasonNavigationIssue,
    CancelReason.deliveryDelayed => l10n.cancelReasonDeliveryDelayed,
    CancelReason.foodTooLarge => l10n.cancelReasonFoodTooLarge,
    CancelReason.merchantClosed => l10n.cancelReasonMerchantClosed,
    CancelReason.orderReassigned => l10n.cancelReasonOrderReassigned,
    CancelReason.accident => l10n.cancelReasonAccident,
    CancelReason.wrongAddress => l10n.cancelReasonWrongAddress,
    CancelReason.vehicleBreakdown => l10n.cancelReasonVehicleBreakdown,
    CancelReason.customerNoShow => l10n.cancelReasonCustomerNoShow,
    CancelReason.customerRefused => l10n.cancelReasonCustomerRefused,
    CancelReason.restaurantIssue => l10n.cancelReasonRestaurantIssue,
    CancelReason.other => l10n.cancelReasonOther,
  };

  static CancelReason? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final base = raw.split('|').first.trim();
    for (final value in CancelReason.values) {
      if (value.apiValue == base) return value;
    }
    return null;
  }

  static String composeReason(CancelReason reason, {String? note}) {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) return reason.apiValue;
    return '${reason.apiValue}|$trimmed';
  }
}

/// Outcome when finishing an in-transit delivery.
enum FinishOutcome { delivered, cancelled }

/// Driver-submitted delivery row from `public.deliveries`.
class DriverDelivery {
  const DriverDelivery({
    required this.id,
    required this.externalOrderId,
    required this.status,
    this.deliveredAt,
    this.pickupAt,
    this.pickupLat,
    this.pickupLng,
    this.pickupProofUrl,
    this.deliveredLat,
    this.deliveredLng,
    this.orderProofUrl,
    this.cancelledAt,
    this.cancelLat,
    this.cancelLng,
    this.cancelReason,
    this.cancelProofUrl,
    this.rejectionReason,
    this.partnerName,
    this.partnerLogoUrl,
    this.shiftDate,
    this.createdAt,
    this.isEarlyDrop,
    this.isOutOfZone,
    this.ocrMatched,
    this.pickupDeliveryDistanceM,
    this.zoneDistanceM,
  });

  final String id;
  final String externalOrderId;
  final String status;
  final DateTime? deliveredAt;
  final DateTime? pickupAt;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupProofUrl;
  final double? deliveredLat;
  final double? deliveredLng;
  final String? orderProofUrl;
  final DateTime? cancelledAt;
  final double? cancelLat;
  final double? cancelLng;
  final String? cancelReason;
  final String? cancelProofUrl;
  final String? rejectionReason;
  final String? partnerName;
  final String? partnerLogoUrl;
  /// Kuwait shift day (`deliveries.shift_date`). Null on old rows / old APKs.
  final DateTime? shiftDate;
  final DateTime? createdAt;

  /// Integrity verdict written at completion. Null means "not checked".
  final bool? isEarlyDrop;
  final bool? isOutOfZone;
  final bool? ocrMatched;
  final double? pickupDeliveryDistanceM;
  final double? zoneDistanceM;

  bool get isCancelled => status == 'cancelled';
  bool get isInTransit => status == 'in_transit';

  Duration? get deliveryDuration {
    final start = pickupAt;
    final end = deliveredAt ?? cancelledAt;
    if (start == null || end == null) return null;
    return end.difference(start);
  }

  bool get hasDisplayablePartnerLogo {
    final url = partnerLogoUrl?.trim();
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  bool get hasOrderProof {
    final value = orderProofUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasPickupProof {
    final value = pickupProofUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasCancelProof {
    final value = cancelProofUrl?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get hasOrderId {
    final value = externalOrderId.trim();
    return value.isNotEmpty && value != '—';
  }

  String displayOrderId(AppLocalizations l10n) => hasOrderId
      ? OrderId.displayStored(externalOrderId)
      : l10n.notProvided;

  String? cancelReasonLabel(AppLocalizations l10n) {
    final parsed = CancelReason.tryParse(cancelReason);
    if (parsed != null) return parsed.label(l10n);
    return cancelReason?.trim().isNotEmpty == true ? cancelReason : null;
  }

  /// Sort/display timestamp: delivered, cancelled, pickup, or created fallback.
  DateTime? get primaryTimestamp =>
      deliveredAt ?? cancelledAt ?? pickupAt ?? createdAt;

  factory DriverDelivery.fromJson(Map<String, dynamic> json) {
    final partners = json['partners'];
    Map<String, dynamic>? partnerMap;
    if (partners is Map) {
      partnerMap = Map<String, dynamic>.from(partners);
    } else if (partners is List &&
        partners.isNotEmpty &&
        partners.first is Map) {
      partnerMap = Map<String, dynamic>.from(partners.first as Map);
    }

    return DriverDelivery(
      id: json['id']?.toString() ?? '',
      externalOrderId: json['external_order_id']?.toString() ?? '—',
      status: json['status']?.toString() ?? 'pending',
      deliveredAt: parseDeliveryTimestamp(json['delivered_at']),
      pickupAt: parseDeliveryTimestamp(json['pickup_at']),
      pickupLat: parseDeliveryDouble(json['pickup_lat']),
      pickupLng: parseDeliveryDouble(json['pickup_lng']),
      pickupProofUrl: _optionalText(json['pickup_proof_url']),
      deliveredLat: parseDeliveryDouble(json['delivered_lat']),
      deliveredLng: parseDeliveryDouble(json['delivered_lng']),
      orderProofUrl: _optionalText(json['order_proof_url']),
      cancelledAt: parseDeliveryTimestamp(json['cancelled_at']),
      cancelLat: parseDeliveryDouble(json['cancel_lat']),
      cancelLng: parseDeliveryDouble(json['cancel_lng']),
      cancelReason: _optionalText(json['cancel_reason']),
      cancelProofUrl: _optionalText(json['cancel_proof_url']),
      rejectionReason: _optionalText(json['rejection_reason']),
      partnerName: partnerMap?['name']?.toString(),
      partnerLogoUrl: partnerMap?['logo_url']?.toString(),
      shiftDate: parseDeliveryDateOnly(json['shift_date']),
      createdAt: parseDeliveryTimestamp(json['created_at']),
      isEarlyDrop: _optionalBool(json['is_early_drop']),
      isOutOfZone: _optionalBool(json['is_out_of_zone']),
      ocrMatched: _optionalBool(json['order_proof_ocr_matched']),
      pickupDeliveryDistanceM: parseDeliveryDouble(
        json['pickup_delivery_distance_m'],
      ),
      zoneDistanceM: parseDeliveryDouble(json['zone_distance_m']),
    );
  }
}

/// `driverListMyDeliveries` returns raw Firestore docs. Timestamps arrive as
/// `{_seconds,_nanoseconds}` maps, not ISO strings. A single `as String?`
/// used to blank the whole list.
DateTime? parseDeliveryTimestamp(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
  if (raw is num) {
    final n = raw.toInt();
    if (n > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
  }
  if (raw is Map) {
    final seconds = raw['_seconds'] ?? raw['seconds'];
    final nanos = raw['_nanoseconds'] ?? raw['nanoseconds'] ?? raw['nanos'];
    if (seconds is num) {
      final ms = seconds.toInt() * 1000 +
          (nanos is num ? nanos.toInt() ~/ 1000000 : 0);
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    if (seconds is String) {
      final parsed = int.tryParse(seconds);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true);
      }
    }
    final iso = raw['__time__'] ?? raw['iso'];
    if (iso is String) return DateTime.tryParse(iso);
  }
  return null;
}

bool? _optionalBool(Object? raw) => raw is bool ? raw : null;

double? parseDeliveryDouble(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}

DateTime? parseDeliveryDateOnly(Object? raw) {
  if (raw is String && raw.isNotEmpty) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
    if (match != null) {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }
  }
  return parseDeliveryTimestamp(raw);
}

String? _optionalText(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString();
  return text.isEmpty ? null : text;
}

/// Skip a bad row instead of failing the list. [onSkip] gets id + reason.
List<DriverDelivery> parseDriverDeliveries(
  Iterable<Map<String, dynamic>> rows, {
  void Function(String id, String reason)? onSkip,
}) {
  final out = <DriverDelivery>[];
  for (final row in rows) {
    final id = row['id']?.toString() ?? '';
    try {
      final parsed = DriverDelivery.fromJson(row);
      if (parsed.id.isEmpty) {
        onSkip?.call(id, 'missing_id');
        continue;
      }
      out.add(parsed);
    } catch (error) {
      onSkip?.call(id.isEmpty ? '?' : id, error.toString());
    }
  }
  return List<DriverDelivery>.unmodifiable(out);
}

/// In-progress pickup returned by `driver_get_active_pickup`.
class ActiveDelivery {
  const ActiveDelivery({
    required this.id,
    required this.externalOrderId,
    required this.pickupAt,
    this.pickupProofUrl,
    this.partnerName,
  });

  final String id;
  final String externalOrderId;
  final DateTime pickupAt;
  final String? pickupProofUrl;
  final String? partnerName;

  factory ActiveDelivery.fromJson(Map<String, dynamic> json) {
    final pickupAt = parseDeliveryTimestamp(json['pickup_at']) ??
        parseDeliveryTimestamp(json['created_at']) ??
        DateTime.now();
    return ActiveDelivery(
      id: json['id']?.toString() ?? '',
      externalOrderId: json['external_order_id']?.toString() ?? '',
      pickupAt: pickupAt,
      pickupProofUrl: _optionalText(json['pickup_proof_url']),
      partnerName: null,
    );
  }

  factory ActiveDelivery.fromDelivery(DriverDelivery d) {
    return ActiveDelivery(
      id: d.id,
      externalOrderId: d.externalOrderId,
      pickupAt: d.pickupAt ?? DateTime.now(),
      pickupProofUrl: d.pickupProofUrl,
      partnerName: d.partnerName,
    );
  }
}

class CreatedDelivery {
  const CreatedDelivery({
    required this.id,
    required this.externalOrderId,
    required this.status,
    this.deliveredAt,
    this.pickupAt,
  });

  final String id;
  final String externalOrderId;
  final String status;
  final DateTime? deliveredAt;
  final DateTime? pickupAt;

  factory CreatedDelivery.fromJson(Map<String, dynamic> json) {
    return CreatedDelivery(
      id: json['id']?.toString() ?? '',
      externalOrderId: json['external_order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      deliveredAt: parseDeliveryTimestamp(json['delivered_at']),
      pickupAt: parseDeliveryTimestamp(json['pickup_at']),
    );
  }
}
