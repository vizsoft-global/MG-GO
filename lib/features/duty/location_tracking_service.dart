import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/l10n/localizations_loader.dart';
import '../../core/offline/network_status_provider.dart';
import '../../core/offline/offline_repo.dart';
import 'adaptive_location_scheduler.dart';
import 'duty_session_storage.dart';

class LocationTrackingException implements Exception {
  LocationTrackingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A non-2xx answer from the direct REST path, keeping the status the
/// foreground service needs to decide *whether retrying can ever help*.
///
/// A 401 means PostgREST refused the JWT — the token on disk has expired and
/// no amount of retrying with it will succeed. `driver_off_duty` means the
/// server has already clocked this rider out, so the service posting the fix
/// has outlived its session. Both used to be caught as a bare exception and
/// retried at the watchdog cadence forever; on production that was ~78k
/// rejected calls in two hours from 57 phones.
class LocationTrackingHttpException extends LocationTrackingException {
  LocationTrackingHttpException(super.message, {required this.statusCode});

  final int statusCode;

  /// PostgREST rejected the bearer token itself (expired or invalid).
  bool get isAuthRejected => statusCode == 401;

  /// `driver_report_location` raised because `drivers.is_on_duty` is false.
  bool get isOffDuty => message.toLowerCase().contains('driver_off_duty');
}

Future<int?> readBatteryPct() async {
  try {
    return await Battery().batteryLevel;
  } catch (_) {
    return null;
  }
}

class LocationReportExtras {
  const LocationReportExtras({
    this.headingDeg,
    this.headingSource,
    this.compassDeg,
    this.altitudeM,
    this.networkType,
    this.chargingState,
    this.isMocked,
    this.locationProvider,
    this.activeDeliveryId,
  });

  /// The fused bearing — GPS course while moving, compass at a standstill. Keeps
  /// its original meaning so `driver_report_location` needs no new parameter.
  final double? headingDeg;

  /// Which sensor [headingDeg] came from. Edge-only: the durable RPC has a fixed
  /// signature, and a bearing's provenance is a live-map concern, not history.
  final String? headingSource;

  /// Raw smoothed compass bearing, sent alongside the fused value so the edge
  /// can tell a phone that has been rotated in its mount from a bike that turned.
  final double? compassDeg;
  final double? altitudeM;
  final String? networkType;
  final String? chargingState;
  final bool? isMocked;
  final String? locationProvider;
  final String? activeDeliveryId;

  Map<String, dynamic> toRpcParams() => {
    'p_heading_deg': headingDeg,
    'p_altitude_m': altitudeM,
    'p_network_type': networkType,
    'p_charging_state': chargingState,
    'p_is_mocked': isMocked,
    'p_location_provider': locationProvider,
    'p_active_delivery_id': activeDeliveryId,
  };
}

class LocationTrackingService {
  LocationTrackingService(this._client, this._offlineRepo, this._networkStatus);

  final SupabaseClient _client;
  final OfflineRepo _offlineRepo;
  final NetworkStatusController _networkStatus;

  Future<LocationReportResult> reportLocation({
    required double latitude,
    required double longitude,
    double? speedMps,
    double? accuracyMeters,
    int? batteryPct,
    required TrackingStatus trackingStatus,
    String? deliveryId,
    bool forceHistory = false,
    LocationReportExtras extras = const LocationReportExtras(),
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (_networkStatus.isOffline && userId != null) {
      await _offlineRepo.queueLocation(
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        trackingStatus: trackingStatus.apiValue,
        speedMps: speedMps,
        accuracyMeters: accuracyMeters,
        batteryPct: batteryPct,
        deliveryId: deliveryId,
        forceHistory: forceHistory,
        headingDeg: extras.headingDeg,
        altitudeM: extras.altitudeM,
        networkType: extras.networkType,
        chargingState: extras.chargingState,
        isMocked: extras.isMocked,
        locationProvider: extras.locationProvider,
        activeDeliveryId: extras.activeDeliveryId,
      );
      return const LocationReportResult(
        zoneStatus: 'unknown',
        inRange: true,
        lastSeenAt: null,
        historyWritten: false,
        trackingStatus: 'queued',
      );
    }
    try {
      final result = await _client.rpc(
        'driver_report_location',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_speed_mps': speedMps,
          'p_accuracy_meters': accuracyMeters,
          'p_battery_pct': batteryPct,
          'p_tracking_status': trackingStatus.apiValue,
          'p_delivery_id': deliveryId,
          'p_force_history': forceHistory,
          ...extras.toRpcParams(),
        },
      );
      final map = result is Map<String, dynamic>
          ? result
          : Map<String, dynamic>.from(result as Map);
      _networkStatus.recordRpcSuccess();
      return LocationReportResult.fromJson(map);
    } on PostgrestException catch (e) {
      _networkStatus.recordRpcFailure();
      if (userId != null && _isRecoverableNetworkError(e.message)) {
        await _offlineRepo.queueLocation(
          userId: userId,
          latitude: latitude,
          longitude: longitude,
          trackingStatus: trackingStatus.apiValue,
          speedMps: speedMps,
          accuracyMeters: accuracyMeters,
          batteryPct: batteryPct,
          deliveryId: deliveryId,
          forceHistory: forceHistory,
          headingDeg: extras.headingDeg,
          altitudeM: extras.altitudeM,
          networkType: extras.networkType,
          chargingState: extras.chargingState,
          isMocked: extras.isMocked,
          locationProvider: extras.locationProvider,
          activeDeliveryId: extras.activeDeliveryId,
        );
        return const LocationReportResult(
          zoneStatus: 'unknown',
          inRange: true,
          lastSeenAt: null,
          historyWritten: false,
          trackingStatus: 'queued',
        );
      }
      throw LocationTrackingException(await _friendlyError(e.message));
    }
  }

  Future<String> _friendlyError(String message) async {
    final l10n = await loadSavedLocalizations();
    final lower = message.toLowerCase();
    if (lower.contains('driver_off_duty')) {
      return l10n.mustBeOnDutyToReportLocation;
    }
    if (lower.contains('not_authenticated')) {
      return l10n.sessionExpired;
    }
    if (lower.contains('could not find the function')) {
      return l10n.serverUpdateRequired;
    }
    return message.isEmpty ? l10n.couldNotReportLocation : message;
  }

  bool _isRecoverableNetworkError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('connection');
  }
}

Future<LocationReportResult> reportLocationViaHttp({
  required String accessToken,
  required double latitude,
  required double longitude,
  double? speedMps,
  double? accuracyMeters,
  int? batteryPct,
  required TrackingStatus trackingStatus,
  String? deliveryId,
  bool forceHistory = false,
  LocationReportExtras extras = const LocationReportExtras(),
}) async {
  final uri = Uri.parse(
    '${Env.supabaseUrl}/rest/v1/rpc/driver_report_location',
  );
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'apikey': Env.supabaseAnonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_speed_mps': speedMps,
      'p_accuracy_meters': accuracyMeters,
      'p_battery_pct': batteryPct,
      'p_tracking_status': trackingStatus.apiValue,
      'p_delivery_id': deliveryId,
      'p_force_history': forceHistory,
      ...extras.toRpcParams(),
    }),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw LocationTrackingHttpException(
      await decodeRpcError(response.body),
      statusCode: response.statusCode,
    );
  }

  final map = jsonDecode(response.body) as Map<String, dynamic>;
  return LocationReportResult.fromJson(map);
}

Future<Map<String, dynamic>> setDutyStateViaHttp({
  required String accessToken,
  required bool isOnDuty,
  required bool isOnline,
}) async {
  final uri = Uri.parse('${Env.supabaseUrl}/rest/v1/rpc/driver_set_duty_state');
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'apikey': Env.supabaseAnonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'p_is_on_duty': isOnDuty, 'p_is_online': isOnline}),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw LocationTrackingException(await decodeRpcError(response.body));
  }

  return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
}

Future<Map<String, dynamic>> clearLiveLocationViaHttp({
  required String accessToken,
}) async {
  final uri = Uri.parse(
    '${Env.supabaseUrl}/rest/v1/rpc/driver_clear_live_location',
  );
  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'apikey': Env.supabaseAnonKey,
      'Content-Type': 'application/json',
    },
    body: '{}',
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw LocationTrackingException(await decodeRpcError(response.body));
  }

  return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
}

/// Re-reads the duty session from disk. Only the foreground service needs this; the UI
/// isolate is the writer and its cache is never behind. See [DutySessionStorage].
Future<void> reloadDutySession() => DutySessionStorage.reload();

Future<String?> readDutyAccessToken() => DutySessionStorage.readAccessToken();

Future<void> persistDutyAccessToken(String token) =>
    DutySessionStorage.saveAccessToken(token);

Future<void> clearDutyAccessToken() => DutySessionStorage.clearAccessToken();

Future<String?> readActiveDeliveryId() =>
    DutySessionStorage.readActiveDeliveryId();

Future<int> readDutyStateVersion() => DutySessionStorage.readDutyStateVersion();

Future<int> bumpDutyStateVersion() => DutySessionStorage.bumpDutyStateVersion();
