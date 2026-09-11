import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/create_attachment.dart';
import 'assigned_vehicle.dart';

class VehicleServiceException implements Exception {
  VehicleServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class VehicleService {
  VehicleService(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return {};
  }

  Future<AssignedVehicle?> getAssignedVehicle() async {
    final result = await _client.rpc('driver_get_assigned_vehicle');
    return AssignedVehicle.fromJson(result);
  }

  Future<void> reportFuelFill({
    required double litres,
    required double costKwd,
    required String stationName,
    required double lat,
    required double lng,
    required List<Map<String, dynamic>> attachments,
    DateTime? filledAt,
  }) async {
    final result = await _client.rpc(
      'driver_report_fuel_fill',
      params: {
        'p_litres': litres,
        'p_cost_kwd': costKwd,
        'p_station_name': stationName,
        'p_lat': lat,
        'p_lng': lng,
        'p_attachments': attachments,
        if (filledAt != null) 'p_filled_at': filledAt.toUtc().toIso8601String(),
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      final code = map['error']?.toString() ?? 'fill_failed';
      throw VehicleServiceException(code, code: code);
    }
  }

  Future<Map<String, dynamic>> uploadFillAttachment({
    required CreateAttachmentSpec spec,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    required DateTime capturedAt,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw VehicleServiceException('not_authenticated', code: 'not_authenticated');
    }
    final key =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_${spec.kind}.jpg';
    await _client.storage.from('fuel-fills').uploadBinary(
          key,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return createAttachmentPayload(
      storageKey: key,
      fileName: fileName,
      contentType: contentType,
      byteSize: bytes.length,
      title: spec.titleEn,
      kind: spec.kind,
      capturedAt: capturedAt,
    );
  }
}
