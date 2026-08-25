import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'request_form_submit.dart';
import 'request_type_definition.dart';
import 'support_models.dart';

class SupportService {
  SupportService(this._client);

  final SupabaseClient _client;

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
    final result = await _client.rpc(
      'driver_list_my_requests',
      params: {
        'p_status': status,
        'p_limit': 50,
        'p_offset': 0,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'list_failed');
    }
    return _asMapList(map['rows'])
        .map(SupportRequestSummary.fromJson)
        .toList();
  }

  Future<SupportRequestDetail> getRequest(String id) async {
    final result = await _client.rpc(
      'driver_get_request',
      params: {'p_request_id': id},
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'not_found');
    }
    return SupportRequestDetail(
      request: _asMap(map['request']),
      steps: _asMapList(map['steps']),
      clarifications: _asMapList(map['clarifications']),
      attachments: _asMapList(map['attachments']),
    );
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
    final result = await _client.rpc(
      'driver_create_request',
      params: {
        'p_type': type,
        'p_payload': payload,
        'p_attachments': attachments,
        'p_amount_kwd': amountKwd,
        'p_start_date': isoDateOnly(startDate),
        'p_end_date': isoDateOnly(endDate),
        'p_details': details,
        'p_severity': severity,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'create_failed');
    }
    return (
      id: map['id'] as String,
      requestCode: map['request_code'] as String? ?? '',
    );
  }

  Future<void> submitClarification({
    required String requestId,
    required String answer,
    List<String> attachmentKeys = const [],
  }) async {
    final result = await _client.rpc(
      'driver_submit_clarification',
      params: {
        'p_request_id': requestId,
        'p_answer': answer,
        'p_attachment_keys': attachmentKeys,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'clarify_failed');
    }
  }

  Future<void> acknowledgeRequest({
    required String requestId,
    String? note,
  }) async {
    final result = await _client.rpc(
      'driver_acknowledge_request',
      params: {
        'p_request_id': requestId,
        'p_note': note,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'ack_failed');
    }
  }

  /// An approver proposed different dates. Accepting applies them and sends the request back
  /// to the same approver; declining sends it back with the driver's reason attached.
  Future<void> respondToReschedule({
    required String requestId,
    required bool accept,
    String? note,
  }) async {
    final result = await _client.rpc(
      'driver_respond_reschedule',
      params: {
        'p_request_id': requestId,
        'p_accept': accept,
        'p_note': note,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'reschedule_reply_failed');
    }
  }

  /// Request types the admin has published. Drives the hub tiles, so a type
  /// added in the panel appears without an app release.
  Future<List<RequestTypeDefinition>> listRequestTypes() async {
    final rows = await _client
        .from('request_type_definitions')
        .select(
          'key, label_en, label_ar, icon_key, is_system, sort_order, '
          'date_range_required, min_attachments, attachments_error_code',
        )
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List)
        .map((e) =>
            RequestTypeDefinition.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<RequestFieldDefinition>> listRequestFields(String typeKey) async {
    final rows = await _client
        .from('request_field_definitions')
        .select(
          'field_key, label_en, label_ar, kind, target, is_required, '
          'sort_order, options_source, options, min_value, max_value, '
          'help_en, help_ar',
        )
        .eq('type_key', typeKey)
        .order('sort_order');
    return (rows as List)
        .map((e) =>
            RequestFieldDefinition.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<LoanTenureOption>> listTenureOptions() async {
    final rows = await _client
        .from('loan_tenure_options')
        .select('months, label')
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List)
        .map((e) => LoanTenureOption.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ComplaintCategory>> listComplaintCategories() async {
    final rows = await _client
        .from('complaint_categories')
        .select('key, label_en, label_ar')
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List)
        .map((e) => ComplaintCategory.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<VisitBranch?> getCentralTowerBranch() async {
    final rows = await _client
        .from('visit_branches')
        .select('id, key, name, address, working_hours, contact_phone')
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('sort_order')
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return VisitBranch.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  /// Departments offered at [branchId]. A department with a null `branch_id` is
  /// offered everywhere; one pinned to another branch must not be bookable here.
  Future<List<VisitDepartment>> listVisitDepartments({String? branchId}) async {
    var query = _client
        .from('visit_departments')
        .select('key, label_en, label_ar, branch_id')
        .eq('is_active', true);
    if (branchId != null) {
      query = query.or('branch_id.is.null,branch_id.eq.$branchId');
    }
    final rows = await query.order('sort_order');
    return (rows as List)
        .map((e) => VisitDepartment.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((d) => kVisitDepartmentKeys.contains(d.key))
        .toList();
  }

  Future<List<VisitSlotOption>> listVisitSlots({
    required DateTime date,
    required String departmentKey,
  }) async {
    final result = await _client.rpc(
      'driver_list_visit_slots',
      params: {
        'p_date': date.toIso8601String().split('T').first,
        'p_department_key': departmentKey,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'slots_failed');
    }
    return _asMapList(map['slots']).map(VisitSlotOption.fromJson).toList();
  }

  Future<({String id, String bookingCode})> bookVisit({
    required String departmentKey,
    required DateTime date,
    required String slotId,
    String? note,
  }) async {
    final result = await _client.rpc(
      'driver_book_visit',
      params: {
        'p_department_key': departmentKey,
        'p_date': date.toIso8601String().split('T').first,
        'p_slot_id': slotId,
        'p_note': note,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      final code = map['error']?.toString() ?? 'book_failed';
      final message = map['message']?.toString();
      throw Exception(message ?? code);
    }
    return (
      id: map['id'] as String,
      bookingCode: map['booking_code'] as String? ?? '',
    );
  }

  Future<void> cancelVisit(String bookingId) async {
    final result = await _client.rpc(
      'driver_cancel_visit',
      params: {'p_booking_id': bookingId},
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'cancel_failed');
    }
  }

  Future<List<VisitBooking>> listMyVisits() async {
    final rows = await _client
        .from('visit_bookings')
        .select(
          'id, booking_code, department_key, scheduled_date, status, note',
        )
        .order('scheduled_date', ascending: false);
    return (rows as List)
        .map((e) => VisitBooking.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<EsignRequestSummary>> listEsignRequests() async {
    final result = await _client.rpc(
      'driver_list_esign_requests',
      params: {'p_limit': 50, 'p_offset': 0},
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'list_failed');
    }
    return _asMapList(map['rows'])
        .map(EsignRequestSummary.fromJson)
        .toList();
  }

  Future<EsignRequestDetail> getEsignRequest(String id) async {
    final result = await _client.rpc(
      'driver_get_esign_request',
      params: {'p_id': id},
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'not_found');
    }
    return EsignRequestDetail(raw: _asMap(map['request']));
  }

  Future<String> uploadEsignSignature({
    required String requestId,
    required Uint8List pngBytes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('not_authenticated');
    final key = '$uid/$requestId/signature.png';
    await _client.storage.from('esign-documents').uploadBinary(
          key,
          pngBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );
    return key;
  }

  /// Asks the server to compose the signature-stamped copy.
  ///
  /// The device only triggers this; the edge function runs with the service
  /// role, re-reads the original document, and is the sole writer of
  /// `signed_document_storage_key`. Safe to call repeatedly — it overwrites a
  /// deterministic object key rather than stamping again.
  Future<String?> composeSignedEsignDocument(String requestId) async {
    try {
      final response = await _client.functions.invoke(
        'esign-compose-signed-document',
        body: {'request_id': requestId},
      );
      final map = _asMap(response.data);
      if (map['ok'] != true) {
        throw Exception(map['error']?.toString() ?? 'compose_failed');
      }
      return map['storage_key'] as String?;
    } on FunctionException catch (e) {
      final map = _asMap(e.details);
      throw Exception(map['error']?.toString() ?? 'compose_failed');
    }
  }

  Future<String?> signedEsignDocumentUrl(String storageKey) async {
    if (storageKey.trim().isEmpty) return null;
    return _client.storage
        .from('esign-documents')
        .createSignedUrl(storageKey, 3600);
  }

  Future<void> submitEsignature({
    required String requestId,
    required String signatureStorageKey,
    String? signerDisplayName,
    Map<String, dynamic> signerMeta = const {},
  }) async {
    final result = await _client.rpc(
      'driver_submit_esignature',
      params: {
        'p_id': requestId,
        'p_signature_storage_key': signatureStorageKey,
        'p_signer_display_name': signerDisplayName,
        'p_signer_meta': signerMeta,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'sign_failed');
    }
  }

  /// Records the first time the rider opened the document. The server keeps the
  /// earliest stamp, so re-opening is harmless.
  Future<void> markEsignViewed(String requestId) async {
    await _client.rpc('driver_mark_esign_viewed', params: {'p_id': requestId});
  }

  Future<void> declineEsignature({
    required String requestId,
    String? reason,
  }) async {
    final result = await _client.rpc(
      'driver_decline_esignature',
      params: {'p_id': requestId, 'p_reason': reason},
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'decline_failed');
    }
  }

  Future<List<DriverAppointment>> listAppointments() async {
    final result = await _client.rpc(
      'driver_list_appointments',
      params: {'p_limit': 50, 'p_offset': 0},
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'list_failed');
    }
    return _asMapList(map['rows'])
        .map(DriverAppointment.fromJson)
        .toList();
  }

  Future<String> respondAppointment({
    required String appointmentId,
    required String action,
    DateTime? proposedFor,
    String? note,
  }) async {
    final result = await _client.rpc(
      'driver_respond_appointment',
      params: {
        'p_id': appointmentId,
        'p_action': action,
        'p_proposed_for': proposedFor?.toIso8601String(),
        'p_note': note,
      },
    );
    final map = _asMap(result);
    if (map['ok'] == false) {
      throw Exception(map['error']?.toString() ?? 'respond_failed');
    }
    return map['status']?.toString() ?? '';
  }
}
