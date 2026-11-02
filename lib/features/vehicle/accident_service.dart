import 'package:cloud_functions/cloud_functions.dart';

import '../../core/firebase/rider_backend.dart';
import 'my_accident.dart';

class AccidentServiceException implements Exception {
  AccidentServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// The two accident callables. Uploading is `DriverUploadService`, which already
/// owns presign → PUT → confirm and the proxy fallback.
class AccidentService {
  AccidentService();

  Future<List<MyAccident>> listMyAccidents() async {
    try {
      final result = await callRiderFunction('driverListMyAccidents');
      final raw = result['accidents'];
      if (raw is! List) return const <MyAccident>[];
      return raw
          .map(MyAccident.fromJson)
          .whereType<MyAccident>()
          .toList(growable: false);
    } on FirebaseFunctionsException catch (e) {
      final code = riderErrorCode(e);
      throw AccidentServiceException(code, code: code);
    }
  }

  /// Returns the allocated reference (`ACC-0001`).
  Future<String> reportAccident({
    required DateTime occurredAt,
    required String locationText,
    double? lat,
    double? lng,
    String? otherPartyName,
    String? otherPartyPlate,
    String? otherPartyPhone,
    String? description,
    required List<String> attachmentKeys,
  }) async {
    try {
      final payload = <String, dynamic>{
        'p_occurred_at': occurredAt.toUtc().toIso8601String(),
        'p_location_text': locationText,
        'p_attachment_keys': attachmentKeys,
      };
      if (lat != null) payload['p_location_lat'] = lat;
      if (lng != null) payload['p_location_lng'] = lng;
      final name = (otherPartyName ?? '').trim();
      if (name.isNotEmpty) payload['p_other_party_name'] = name;
      final plate = (otherPartyPlate ?? '').trim();
      if (plate.isNotEmpty) payload['p_other_party_plate'] = plate;
      final phone = (otherPartyPhone ?? '').trim();
      if (phone.isNotEmpty) payload['p_other_party_phone'] = phone;
      final text = (description ?? '').trim();
      if (text.isNotEmpty) payload['p_description'] = text;

      final map = await callRiderFunction('driverReportAccident', payload);
      if (map['ok'] == false) {
        final code = map['error']?.toString() ?? 'report_failed';
        throw AccidentServiceException(code, code: code);
      }
      return map['reference']?.toString() ?? '';
    } on FirebaseFunctionsException catch (e) {
      final code = riderErrorCode(e);
      throw AccidentServiceException(code, code: code);
    }
  }
}
