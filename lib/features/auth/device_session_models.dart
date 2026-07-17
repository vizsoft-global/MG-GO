import 'driver_access.dart';

class ActiveDeviceInfo {
  const ActiveDeviceInfo({
    required this.deviceId,
    this.deviceModel,
    this.deviceManufacturer,
    this.lastSeenAt,
  });

  factory ActiveDeviceInfo.fromJson(Map<String, dynamic> json) {
    return ActiveDeviceInfo(
      deviceId: json['device_id'] as String? ?? '',
      deviceModel: json['device_model'] as String?,
      deviceManufacturer: json['device_manufacturer'] as String?,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
    );
  }

  final String deviceId;
  final String? deviceModel;
  final String? deviceManufacturer;
  final DateTime? lastSeenAt;

  String label({String unknown = 'Unknown device'}) {
    final parts = <String>[
      if (deviceManufacturer != null && deviceManufacturer!.trim().isNotEmpty)
        deviceManufacturer!.trim(),
      if (deviceModel != null && deviceModel!.trim().isNotEmpty)
        deviceModel!.trim(),
    ];
    if (parts.isEmpty) return unknown;
    return parts.join(' ');
  }
}

class DeviceConflictException implements Exception {
  const DeviceConflictException({required this.activeDevice});

  final ActiveDeviceInfo activeDevice;

  @override
  String toString() => 'DeviceConflictException(${activeDevice.label()})';
}

class DeviceHeartbeatResult {
  const DeviceHeartbeatResult({
    required this.ok,
    required this.kicked,
    required this.flushGraceActive,
    this.flushDeadlineAt,
    this.activeDevice,
    this.blocked = false,
    this.blockReason,
  });

  factory DeviceHeartbeatResult.fromJson(Map<String, dynamic> json) {
    final activeRaw = json['active_device'];
    final blocked = DriverAccessParser.looksBlocked(json);
    return DeviceHeartbeatResult(
      ok: json['ok'] == true,
      kicked: json['kicked'] == true,
      flushGraceActive: json['flush_grace_active'] == true,
      flushDeadlineAt: json['flush_deadline_at'] != null
          ? DateTime.tryParse(json['flush_deadline_at'] as String)
          : null,
      activeDevice: activeRaw is Map
          ? ActiveDeviceInfo.fromJson(Map<String, dynamic>.from(activeRaw))
          : null,
      blocked: blocked,
      blockReason: DriverAccessParser.reasonFromMap(json),
    );
  }

  final bool ok;
  final bool kicked;
  final bool flushGraceActive;
  final DateTime? flushDeadlineAt;
  final ActiveDeviceInfo? activeDevice;
  final bool blocked;
  final String? blockReason;
}
