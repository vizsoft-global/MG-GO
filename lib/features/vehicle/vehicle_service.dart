import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/firebase/rider_backend.dart';
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
  VehicleService();

  Future<AssignedVehicle?> getAssignedVehicle() async {
    try {
      final result = await callRiderFunction('driverGetAssignedVehicle');
      return AssignedVehicle.fromJson(result);
    } on FirebaseFunctionsException catch (e) {
      final code = riderErrorCode(e);
      throw VehicleServiceException(code, code: code);
    }
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
    try {
      final map = await callRiderFunction('driverReportFuelFill', {
        'p_litres': litres,
        'p_cost_kwd': costKwd,
        'p_station_name': stationName,
        'p_lat': lat,
        'p_lng': lng,
        'p_attachments': attachments,
        if (filledAt != null) 'p_filled_at': filledAt.toUtc().toIso8601String(),
      });
      if (map['ok'] == false) {
        final code = map['error']?.toString() ?? 'fill_failed';
        throw VehicleServiceException(code, code: code);
      }
    } on FirebaseFunctionsException catch (e) {
      final code = riderErrorCode(e);
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw VehicleServiceException('not_authenticated', code: 'not_authenticated');
    }
    final key =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_${spec.kind}.jpg';
    try {
      final map = await callRiderFunction('driverGetUploadUrl', {
        'bucket': 'fuel-fills',
        'object_key': key,
        'content_type': contentType,
      });
      final url = map['url']?.toString() ?? '';
      final storedKey = map['object_key']?.toString().trim();
      if (url.isEmpty) {
        throw VehicleServiceException('upload_url_missing', code: 'upload_url_missing');
      }
      final res = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': contentType},
        body: bytes,
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw VehicleServiceException('upload_failed', code: 'upload_failed');
      }
      return createAttachmentPayload(
        storageKey: (storedKey != null && storedKey.isNotEmpty) ? storedKey : key,
        fileName: fileName,
        contentType: contentType,
        byteSize: bytes.length,
        title: spec.titleEn,
        kind: spec.kind,
        capturedAt: capturedAt,
      );
    } on FirebaseFunctionsException catch (e) {
      final code = riderErrorCode(e);
      throw VehicleServiceException(code, code: code);
    }
  }
}
