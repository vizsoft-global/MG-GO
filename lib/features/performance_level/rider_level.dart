import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/rider_backend.dart';

class RiderLevelMetrics {
  const RiderLevelMetrics({
    required this.activeDays,
    required this.mtdVerifiedDeliveries,
    required this.targetDpd,
    required this.requiredOrders,
    required this.gap,
    required this.dpd,
  });

  final int activeDays;
  final int mtdVerifiedDeliveries;
  final num targetDpd;
  final int requiredOrders;
  final int gap;
  final num dpd;

  factory RiderLevelMetrics.fromMap(Map<String, dynamic>? map) {
    return RiderLevelMetrics(
      activeDays: _asInt(map?['active_days']),
      mtdVerifiedDeliveries: _asInt(map?['mtd_verified_deliveries']),
      targetDpd: _asNum(map?['target_dpd']),
      requiredOrders: _asInt(map?['required_orders']),
      gap: _asInt(map?['gap']),
      dpd: _asNum(map?['dpd']),
    );
  }
}

class RiderLevel {
  const RiderLevel({
    required this.level,
    required this.autoLevel,
    required this.classified,
    required this.overrideLevel,
    required this.metrics,
  });

  final String level;
  final String autoLevel;
  final bool classified;
  final String? overrideLevel;
  final RiderLevelMetrics metrics;

  bool get isLevelD => level == 'D';

  factory RiderLevel.fromMap(Map<String, dynamic> map) {
    final override = map['override_level']?.toString().trim();
    final rawMetrics = map['metrics'];
    return RiderLevel(
      level: (map['level'] ?? 'standard').toString().trim(),
      autoLevel: (map['auto_level'] ?? '').toString(),
      classified: map['classified'] == true,
      overrideLevel: override == null || override.isEmpty ? null : override,
      metrics: RiderLevelMetrics.fromMap(
        rawMetrics is Map ? Map<String, dynamic>.from(rawMetrics) : null,
      ),
    );
  }
}

/// One read shared by Home, Profile, and the explanation screen.
/// Cached by Riverpod until invalidated — not refetched on rebuild.
final riderLevelProvider = FutureProvider<RiderLevel>((ref) async {
  final map = await callRiderFunction('driverGetMyLevel');
  return RiderLevel.fromMap(map);
});

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

num _asNum(Object? raw) {
  if (raw is num) return raw;
  return num.tryParse(raw?.toString() ?? '') ?? 0;
}
