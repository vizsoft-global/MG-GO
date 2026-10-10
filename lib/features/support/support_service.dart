import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/firebase/rider_backend.dart';
import 'create_attachment.dart';
import 'esign_failure.dart';
import 'request_form_submit.dart';
import 'request_type_definition.dart';
import 'support_models.dart';

class SupportService {
  SupportService();

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return {};
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Object>()
        .map((e) => e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<SupportRequestSummary>> listMyRequests({String? status}) async {
    try {
      final map = await callRiderFunction('driverListMyRequests', {
        'p_status': status,
        'p_limit': 50,
        'p_offset': 0,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(map['rows'])
          .map(SupportRequestSummary.fromJson)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<SupportRequestDetail> getRequest(String id) async {
    try {
      final map = await callRiderFunction('driverGetRequest', {
        'p_request_id': id,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'not_found');
      }
      return SupportRequestDetail(
        request: _asMap(map['request']),
        steps: _asMapList(map['steps']),
        clarifications: _asMapList(map['clarifications']),
        attachments: _asMapList(map['attachments']),
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<({String id, String requestCode})> createRequest({
    required String type,
    required Map<String, dynamic> payload,
    List<Map<String, dynamic>> attachments = const [],
    double? amountKwd,
    DateTime? startDate,
    DateTime? endDate,
    String? details,
    String? severity,
  }) async {
    try {
      final map = await callRiderFunction('driverCreateRequest', {
        'p_type': type,
        'p_payload': payload,
        'p_attachments': attachments,
        'p_amount_kwd': amountKwd,
        'p_start_date': isoDateOnly(startDate),
        'p_end_date': isoDateOnly(endDate),
        'p_details': details,
        'p_severity': severity,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'create_failed');
      }
      return (
        id: map['id'] as String,
        requestCode: map['request_code'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<void> submitClarification({
    required String requestId,
    required String answer,
    List<String> attachmentKeys = const [],
  }) async {
    try {
      final map = await callRiderFunction(
        'driverSubmitClarification',
        clarifyRpcParams(
          requestId: requestId,
          answer: answer,
          attachmentKeys: attachmentKeys,
        ),
      );
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'clarify_failed');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<void> acknowledgeRequest({
    required String requestId,
    String? note,
    List<String> attachmentKeys = const [],
  }) async {
    try {
      final map = await callRiderFunction(
        'driverAcknowledgeRequest',
        acknowledgeRpcParams(
          requestId: requestId,
          note: note,
          attachmentKeys: attachmentKeys,
        ),
      );
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'ack_failed');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  /// An approver proposed different dates. Accepting applies them and sends the request back
  /// to the same approver; declining sends it back with the driver's reason attached.
  Future<void> respondToReschedule({
    required String requestId,
    required bool accept,
    String? note,
  }) async {
    try {
      final map = await callRiderFunction('driverRespondReschedule', {
        'p_request_id': requestId,
        'p_accept': accept,
        'p_note': note,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'reschedule_reply_failed');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  /// Request types the admin has published. Drives the hub tiles, so a type
  /// added in the panel appears without an app release.
  Future<List<RequestTypeDefinition>> listRequestTypes() async {
    try {
      final map = await callRiderFunction('driverListRequestTypes');
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(map['rows'] ?? map['items'] ?? map['data'])
          .map(RequestTypeDefinition.fromJson)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<List<RequestFieldDefinition>> listRequestFields(String typeKey) async {
    try {
      final map = await callRiderFunction('driverListRequestFields', {
        'p_type_key': typeKey,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(map['rows'] ?? map['items'] ?? map['data'])
          .map(RequestFieldDefinition.fromJson)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<List<LoanTenureOption>> listTenureOptions() async {
    try {
      final map = await callRiderFunction('driverListTenureOptions');
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(map['rows'] ?? map['items'] ?? map['data'])
          .map(LoanTenureOption.fromJson)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<List<ComplaintCategory>> listComplaintCategories() async {
    try {
      final map = await callRiderFunction('driverListComplaintCategories');
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(map['rows'] ?? map['items'] ?? map['data'])
          .map(ComplaintCategory.fromJson)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<VisitBranch?> getCentralTowerBranch() async {
    try {
      final map = await callRiderFunction('driverGetDefaultVisitBranch');
      if (map['ok'] == false) return null;
      final row = _singleRow(map, const ['branch', 'row']);
      if (row == null) return null;
      return VisitBranch.fromJson(row);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  /// Departments offered at [branchId]. A department with a null `branch_id` is
  /// offered everywhere; one pinned to another branch must not be bookable here.
  Future<List<VisitDepartment>> listVisitDepartments({String? branchId}) async {
    try {
      final map = await callRiderFunction('driverListVisitDepartments', {
        'p_branch_id': ?branchId,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(
        map['rows'] ?? map['departments'] ?? map['items'] ?? map['data'],
      )
          .map(VisitDepartment.fromJson)
          .where((d) => kVisitDepartmentKeys.contains(d.key))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Map<String, dynamic>? _singleRow(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    final rows = _asMapList(map['rows'] ?? map['items'] ?? map['data']);
    if (rows.isNotEmpty) return rows.first;
    if (map['id'] != null || map['key'] != null) {
      return Map<String, dynamic>.from(map)..remove('ok');
    }
    return null;
  }

  Future<List<VisitSlotOption>> listVisitSlots({
    required DateTime date,
    required String departmentKey,
  }) async {
    try {
      final map = await callRiderFunction('driverListVisitSlots', {
        'p_date': date.toIso8601String().split('T').first,
        'p_department_key': departmentKey,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'slots_failed');
      }
      return _asMapList(map['slots']).map(VisitSlotOption.fromJson).toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<({String id, String bookingCode})> bookVisit({
    required String departmentKey,
    required DateTime date,
    required String slotId,
    String? note,
  }) async {
    try {
      final map = await callRiderFunction('driverBookVisit', {
        'p_department_key': departmentKey,
        'p_date': date.toIso8601String().split('T').first,
        'p_slot_id': slotId,
        'p_note': note,
      });
      if (map['ok'] == false) {
        final code = map['error']?.toString() ?? 'book_failed';
        final message = map['message']?.toString();
        throw Exception(message ?? code);
      }
      return (
        id: map['id'] as String,
        bookingCode: map['booking_code'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<void> cancelVisit(String bookingId) async {
    try {
      final map = await callRiderFunction('driverCancelVisit', {
        'p_booking_id': bookingId,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'cancel_failed');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<List<VisitBooking>> listMyVisits() async {
    try {
      final map = await callRiderFunction('driverListMyVisits');
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(
        map['rows'] ?? map['visits'] ?? map['items'] ?? map['data'],
      ).map(VisitBooking.fromJson).toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<List<EsignRequestSummary>> listEsignRequests() async {
    try {
      final map = await callRiderFunction('driverListEsignRequests', {
        'p_limit': 50,
        'p_offset': 0,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(map['rows'])
          .map(EsignRequestSummary.fromJson)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<EsignRequestDetail> getEsignRequest(String id) async {
    try {
      final map = await callRiderFunction('driverGetEsignRequest', {
        'p_id': id,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'not_found');
      }
      return EsignRequestDetail(raw: _asMap(map['request']));
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<String> uploadEsignSignature({
    required String requestId,
    required Uint8List pngBytes,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const EsignFailure('not_authenticated');
    final key = '$uid/$requestId/signature.png';
    return withEsignTimeout(
      () => _putViaUploadUrl(
        bucket: 'esign-documents',
        objectKey: key,
        contentType: 'image/png',
        bytes: pngBytes,
      ),
    );
  }

  /// Compose stays on Next/R2 — there is no rider callable. Re-read the
  /// request and return an already-written signed copy, otherwise null so
  /// the viewer can still open the source document.
  Future<String?> composeSignedEsignDocument(String requestId) async {
    try {
      final detail = await getEsignRequest(requestId);
      final key = detail.signedDocumentStorageKey?.trim();
      if (key != null && key.isNotEmpty) return key;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> signedEsignDocumentUrl(String storageKey) async {
    if (storageKey.trim().isEmpty) return null;
    try {
      final map = await callRiderFunction('driverGetDownloadUrl', {
        'bucket': 'esign-documents',
        'object_key': storageKey,
      });
      final url = map['url']?.toString().trim() ?? '';
      return url.isEmpty ? null : url;
    } on FirebaseFunctionsException catch (e) {
      throw EsignFailure(riderErrorCode(e), detail: e.message);
    }
  }

  Future<String> _putViaUploadUrl({
    required String bucket,
    required String objectKey,
    required String contentType,
    required List<int> bytes,
  }) async {
    try {
      final map = await callRiderFunction('driverGetUploadUrl', {
        'bucket': bucket,
        'object_key': objectKey,
        'content_type': contentType,
      });
      final url = map['url']?.toString() ?? '';
      final key = map['object_key']?.toString().trim();
      if (url.isEmpty) throw const EsignFailure('network');
      final res = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': contentType},
        body: bytes,
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw const EsignFailure('network');
      }
      return (key != null && key.isNotEmpty) ? key : objectKey;
    } on FirebaseFunctionsException catch (e) {
      throw EsignFailure(riderErrorCode(e), detail: e.message);
    }
  }

  Future<void> submitEsignature({
    required String requestId,
    required String signatureStorageKey,
    String? signerDisplayName,
    Map<String, dynamic> signerMeta = const {},
  }) async {
    try {
      final map = await withEsignTimeout(
        () => callRiderFunction('driverSubmitEsignature', {
          'p_id': requestId,
          'p_signature_storage_key': signatureStorageKey,
          'p_signer_display_name': signerDisplayName,
          'p_signer_meta': signerMeta,
        }),
      );
      if (map['ok'] == false) {
        throw EsignFailure(
          map['error']?.toString() ?? 'sign_failed',
          detail: map['message']?.toString(),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      throw EsignFailure(
        riderErrorCode(e),
        detail: e.message,
      );
    }
  }

  /// Records the first time the rider opened the document. The server keeps the
  /// earliest stamp, so re-opening is harmless.
  Future<void> markEsignViewed(String requestId) async {
    try {
      await callRiderFunction('driverMarkEsignViewed', {'p_id': requestId});
    } on FirebaseFunctionsException catch (e) {
      throw EsignFailure(riderErrorCode(e), detail: e.message);
    }
  }

  Future<void> declineEsignature({
    required String requestId,
    String? reason,
  }) async {
    try {
      final map = await withEsignTimeout(
        () => callRiderFunction('driverDeclineEsignature', {
          'p_id': requestId,
          'p_reason': reason,
        }),
      );
      if (map['ok'] == false) {
        throw EsignFailure(
          map['error']?.toString() ?? 'decline_failed',
          detail: map['message']?.toString(),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      throw EsignFailure(
        riderErrorCode(e),
        detail: e.message,
      );
    }
  }

  Future<List<DriverAppointment>> listAppointments() async {
    try {
      final map = await callRiderFunction('driverListAppointments', {
        'p_limit': 50,
        'p_offset': 0,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'list_failed');
      }
      return _asMapList(map['rows'])
          .map(DriverAppointment.fromJson)
          .toList();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }

  Future<String> respondAppointment({
    required String appointmentId,
    required String action,
    DateTime? proposedFor,
    String? note,
  }) async {
    try {
      final map = await callRiderFunction('driverRespondAppointment', {
        'p_id': appointmentId,
        'p_action': action,
        'p_proposed_for': proposedFor?.toIso8601String(),
        'p_note': note,
      });
      if (map['ok'] == false) {
        throw Exception(map['error']?.toString() ?? 'respond_failed');
      }
      return map['status']?.toString() ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw Exception(riderErrorCode(e));
    }
  }
}
