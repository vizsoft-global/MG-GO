import '../../l10n/app_localizations.dart';
import 'order_id.dart';

/// Known cancel reason codes stored in `deliveries.cancel_reason`.
enum CancelReason {
  customerNoShow('customer_no_show'),
  customerRefused('customer_refused'),
  wrongAddress('wrong_address'),
  restaurantIssue('restaurant_issue'),
  accident('accident'),
  other('other');

  const CancelReason(this.apiValue);

  final String apiValue;

  String label(AppLocalizations l10n) => switch (this) {
    CancelReason.customerNoShow => l10n.cancelReasonCustomerNoShow,
    CancelReason.customerRefused => l10n.cancelReasonCustomerRefused,
    CancelReason.wrongAddress => l10n.cancelReasonWrongAddress,
    CancelReason.restaurantIssue => l10n.cancelReasonRestaurantIssue,
    CancelReason.accident => l10n.cancelReasonAccident,
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
      deliveredAt ?? cancelledAt ?? pickupAt;

  factory DriverDelivery.fromJson(Map<String, dynamic> json) {
    final partners = json['partners'];
    Map<String, dynamic>? partnerMap;
    if (partners is Map<String, dynamic>) {
      partnerMap = partners;
    } else if (partners is List && partners.isNotEmpty) {
      partnerMap = Map<String, dynamic>.from(partners.first as Map);
    }

    DateTime? parseTs(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    double? parseDouble(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString());
    }

    return DriverDelivery(
      id: json['id'] as String,
      externalOrderId: json['external_order_id'] as String? ?? '—',
      status: json['status'] as String? ?? 'pending',
      deliveredAt: parseTs(json['delivered_at'] as String?),
      pickupAt: parseTs(json['pickup_at'] as String?),
      pickupLat: parseDouble(json['pickup_lat']),
      pickupLng: parseDouble(json['pickup_lng']),
      pickupProofUrl: json['pickup_proof_url'] as String?,
      deliveredLat: parseDouble(json['delivered_lat']),
      deliveredLng: parseDouble(json['delivered_lng']),
      orderProofUrl: json['order_proof_url'] as String?,
      cancelledAt: parseTs(json['cancelled_at'] as String?),
      cancelLat: parseDouble(json['cancel_lat']),
      cancelLng: parseDouble(json['cancel_lng']),
      cancelReason: json['cancel_reason'] as String?,
      cancelProofUrl: json['cancel_proof_url'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      partnerName: partnerMap?['name'] as String?,
      partnerLogoUrl: partnerMap?['logo_url'] as String?,
    );
  }
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
    final pickupRaw = json['pickup_at'] as String?;
    final createdRaw = json['created_at'] as String?;
    final pickupAt =
        DateTime.tryParse(pickupRaw ?? '') ??
        DateTime.tryParse(createdRaw ?? '') ??
        DateTime.now();
    return ActiveDelivery(
      id: json['id'] as String,
      externalOrderId: json['external_order_id'] as String? ?? '',
      pickupAt: pickupAt,
      pickupProofUrl: json['pickup_proof_url'] as String?,
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
    DateTime? parseTs(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return CreatedDelivery(
      id: json['id'] as String,
      externalOrderId: json['external_order_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      deliveredAt: parseTs(json['delivered_at'] as String?),
      pickupAt: parseTs(json['pickup_at'] as String?),
    );
  }
}
