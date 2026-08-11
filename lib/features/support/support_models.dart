import 'package:flutter/material.dart';

class SupportRequestSummary {
  const SupportRequestSummary({
    required this.id,
    required this.requestCode,
    required this.requestType,
    required this.status,
    this.currentStepLabel,
    this.createdAt,
    this.amountKwd,
    this.awaitingDriverAck = false,
    this.acknowledged = false,
  });

  final String id;
  final String requestCode;
  final String requestType;
  final String status;
  final String? currentStepLabel;
  final DateTime? createdAt;
  final double? amountKwd;
  final bool awaitingDriverAck;
  final bool acknowledged;

  factory SupportRequestSummary.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    final payloadMap = payload is Map
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
    return SupportRequestSummary(
      id: json['id'] as String,
      requestCode: json['request_code'] as String? ?? '',
      requestType: json['request_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      currentStepLabel: json['current_step_label'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      amountKwd: json['amount_kwd'] != null
          ? (json['amount_kwd'] as num).toDouble()
          : null,
      awaitingDriverAck: payloadMap['awaiting_driver_ack'] == true &&
          payloadMap['driver_ack_at'] == null,
      acknowledged: payloadMap['driver_ack_at'] != null,
    );
  }
}

class SupportRequestDetail {
  const SupportRequestDetail({
    required this.request,
    required this.steps,
    required this.clarifications,
    required this.attachments,
  });

  final Map<String, dynamic> request;
  final List<Map<String, dynamic>> steps;
  final List<Map<String, dynamic>> clarifications;
  final List<Map<String, dynamic>> attachments;

  String get id => request['id'] as String;
  String get requestCode => request['request_code'] as String? ?? '';
  String get requestType => request['request_type'] as String? ?? '';
  String get status => request['status'] as String? ?? '';
  String? get currentStepLabel => request['current_step_label'] as String?;
  Map<String, dynamic> get payload {
    final p = request['payload'];
    if (p is Map<String, dynamic>) return p;
    if (p is Map) return Map<String, dynamic>.from(p);
    return {};
  }
}

class VisitDepartment {
  const VisitDepartment({
    required this.key,
    required this.labelEn,
  });

  final String key;
  final String labelEn;

  factory VisitDepartment.fromJson(Map<String, dynamic> json) {
    return VisitDepartment(
      key: json['key'] as String,
      labelEn: json['label_en'] as String? ?? json['key'] as String,
    );
  }
}

/// Figma RSup/12 department icon per `kVisitDepartmentKeys`.
IconData visitDepartmentIcon(String key) {
  switch (key) {
    case 'hr_services':
      return Icons.people_alt_outlined;
    case 'legal':
      return Icons.balance_outlined;
    case 'operations_services':
      return Icons.settings_suggest_outlined;
    case 'exit_process':
      return Icons.logout_outlined;
    case 'documents_signatures':
      return Icons.draw_outlined;
    case 'training':
      return Icons.menu_book_outlined;
    case 'meeting_request':
      return Icons.groups_outlined;
    default:
      return Icons.more_horiz_rounded;
  }
}

/// Figma RSup/11 Central Tower info card — `name`/`address`/`working_hours`/
/// `contact_phone` are all DB-backed (`visit_branches`).
class VisitBranch {
  const VisitBranch({
    required this.key,
    required this.name,
    this.address,
    this.workingHours,
    this.contactPhone,
  });

  final String key;
  final String name;
  final String? address;
  final String? workingHours;
  final String? contactPhone;

  factory VisitBranch.fromJson(Map<String, dynamic> json) {
    return VisitBranch(
      key: json['key'] as String,
      name: json['name'] as String? ?? 'Central Tower',
      address: json['address'] as String?,
      workingHours: json['working_hours'] as String?,
      contactPhone: json['contact_phone'] as String?,
    );
  }
}

class VisitSlotOption {
  const VisitSlotOption({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.booked,
    required this.remaining,
    required this.full,
  });

  final String id;
  final String startTime;
  final String endTime;
  final int capacity;
  final int booked;
  final int remaining;
  final bool full;

  factory VisitSlotOption.fromJson(Map<String, dynamic> json) {
    return VisitSlotOption(
      id: json['id'] as String,
      startTime: json['start_time']?.toString() ?? '',
      endTime: json['end_time']?.toString() ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      booked: (json['booked'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      full: json['full'] as bool? ?? false,
    );
  }
}

class VisitBooking {
  const VisitBooking({
    required this.id,
    required this.bookingCode,
    required this.departmentKey,
    required this.scheduledDate,
    required this.status,
    this.note,
  });

  final String id;
  final String bookingCode;
  final String departmentKey;
  final String scheduledDate;
  final String status;
  final String? note;

  factory VisitBooking.fromJson(Map<String, dynamic> json) {
    return VisitBooking(
      id: json['id'] as String,
      bookingCode: json['booking_code'] as String? ?? '',
      departmentKey: json['department_key'] as String? ?? '',
      scheduledDate: json['scheduled_date']?.toString() ?? '',
      status: json['status'] as String? ?? '',
      note: json['note'] as String?,
    );
  }

  bool get isUpcoming =>
      status == 'confirmed' || status == 'checked_in';
}

class LoanTenureOption {
  const LoanTenureOption({required this.months, required this.label});

  final int months;
  final String label;

  factory LoanTenureOption.fromJson(Map<String, dynamic> json) {
    return LoanTenureOption(
      months: (json['months'] as num).toInt(),
      label: json['label'] as String? ?? '${json['months']} months',
    );
  }
}

class ComplaintCategory {
  const ComplaintCategory({required this.key, required this.labelEn});

  final String key;
  final String labelEn;

  factory ComplaintCategory.fromJson(Map<String, dynamic> json) {
    return ComplaintCategory(
      key: json['key'] as String,
      labelEn: json['label_en'] as String? ?? json['key'] as String,
    );
  }
}

/// Figma RSup/09 status pill: label + semantic color key.
/// `acknowledged` = driver already tapped Acknowledge on an ack-gated request
/// (payload.driver_ack_at set); `awaitingAck` = still needs the driver's ack.
class RequestStatusView {
  const RequestStatusView(this.label, this.colorKey);

  final String label;
  final RequestStatusColor colorKey;

  static RequestStatusView of({
    required String status,
    required bool awaitingAck,
    required bool acknowledged,
  }) {
    if (awaitingAck) return const RequestStatusView('Awaiting ack', RequestStatusColor.amber);
    if (acknowledged) return const RequestStatusView('Acknowledged', RequestStatusColor.green);
    switch (status) {
      case 'pending':
      case 'submitted':
        return const RequestStatusView('Pending', RequestStatusColor.amber);
      case 'in_review':
        return const RequestStatusView('In progress', RequestStatusColor.blue);
      case 'approved':
        return const RequestStatusView('Approved', RequestStatusColor.green);
      case 'needs_clarification':
        return const RequestStatusView('Action required', RequestStatusColor.amber);
      case 'rejected':
        return const RequestStatusView('Rejected', RequestStatusColor.red);
      case 'solved':
        return const RequestStatusView('Solved', RequestStatusColor.green);
      case 'overdue':
        return const RequestStatusView('Overdue', RequestStatusColor.red);
      default:
        return RequestStatusView(status, RequestStatusColor.grey);
    }
  }
}

enum RequestStatusColor { amber, blue, green, red, grey }

/// Figma User App RSup/12 primary departments (exclude admin-only catalog aliases).
const kVisitDepartmentKeys = <String>{
  'hr_services',
  'legal',
  'operations_services',
  'exit_process',
  'documents_signatures',
  'training',
  'meeting_request',
  'other',
};

const kLeaveTypes = [
  'Annual',
  'Emergency',
  'Accident',
  'Unpaid Leave',
];

const kSickLeaveSubtypes = [
  'Sick leave',
  'Injury',
  'Accident',
  'Other',
];

const kAssetTypes = [
  'SIM card',
  'Fuel card',
  'Fuel limit change',
  'Raincoat',
  'Delivery bag',
  'Reflective vest',
  'Winter jacket',
  'Delivery attire',
  'Delivery pants',
  'New bike',
  'Helmet',
  'Delivery box',
  'Fuel chip',
  'Phone',
  'Mobile holder',
];

const kDocumentTypes = [
  'Civil ID copy',
  'License Copy',
  'Work permit copy',
  'Registration copy',
  'Vehicle document copy',
  'Salary certification',
];

class EsignRequestSummary {
  const EsignRequestSummary({
    required this.id,
    required this.requestCode,
    required this.title,
    required this.status,
    this.dueAt,
    this.signedAt,
    this.screenshotRestricted = true,
    this.categoryKey,
    this.categoryLabel,
    this.createdAt,
  });

  final String id;
  final String requestCode;
  final String title;
  final String status;
  final DateTime? dueAt;
  final DateTime? signedAt;
  final bool screenshotRestricted;
  final String? categoryKey;
  final String? categoryLabel;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
  bool get isSigned => status == 'signed';
  bool get isDeclined => status == 'cancelled';

  factory EsignRequestSummary.fromJson(Map<String, dynamic> json) {
    return EsignRequestSummary(
      id: json['id'] as String,
      requestCode: json['request_code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      dueAt: _parseDate(json['due_at']),
      signedAt: _parseDateTime(json['signed_at']),
      screenshotRestricted: json['screenshot_restricted'] as bool? ?? true,
      categoryKey: json['category_key'] as String?,
      categoryLabel: json['category_label'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

class EsignRequestDetail {
  const EsignRequestDetail({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  String get requestCode => raw['request_code'] as String? ?? '';
  String get title => raw['title'] as String? ?? '';
  String get status => raw['status'] as String? ?? '';
  bool get screenshotRestricted => raw['screenshot_restricted'] as bool? ?? true;
  String? get categoryLabel => raw['category_label'] as String?;
  String? get documentStorageKey => raw['document_storage_key'] as String?;
  String? get signatureStorageKey => raw['signature_storage_key'] as String?;
  String? get signerDisplayName => raw['signer_display_name'] as String?;
  Map<String, dynamic> get signerMeta {
    final meta = raw['signer_meta'];
    if (meta is Map<String, dynamic>) return meta;
    if (meta is Map) return Map<String, dynamic>.from(meta);
    return {};
  }

  DateTime? get dueAt => _parseDate(raw['due_at']);
  DateTime? get signedAt => _parseDateTime(raw['signed_at']);

  bool get isPending => status == 'pending';
  bool get isSigned => status == 'signed';
  bool get isDeclined => status == 'cancelled';
  DateTime? get declinedAt => _parseDateTime(signerMeta['declined_at']);
  String? get declinedReason => signerMeta['declined_reason'] as String?;
}

class DriverAppointment {
  const DriverAppointment({
    required this.id,
    required this.appointmentCode,
    required this.title,
    required this.scheduledFor,
    required this.status,
    this.reason,
    this.locationLabel,
    this.adminNote,
    this.requestedByName,
    this.requestedByRole,
    this.proposedFor,
    this.driverResponseNote,
    this.respondedAt,
    this.createdAt,
  });

  final String id;
  final String appointmentCode;
  final String title;
  final DateTime? scheduledFor;
  final String status;
  final String? reason;
  final String? locationLabel;
  final String? adminNote;
  final String? requestedByName;
  final String? requestedByRole;
  final DateTime? proposedFor;
  final String? driverResponseNote;
  final DateTime? respondedAt;
  final DateTime? createdAt;

  /// RSup/28 — awaiting Accept / Reject / Propose from the driver.
  bool get needsResponse => status == 'pending';

  bool get isUpcoming =>
      status == 'pending' ||
      status == 'accepted' ||
      status == 'scheduled' ||
      status == 'confirmed' ||
      status == 'checked_in';

  factory DriverAppointment.fromJson(Map<String, dynamic> json) {
    return DriverAppointment(
      id: json['id'] as String,
      appointmentCode: json['appointment_code'] as String? ?? '',
      title: json['title'] as String? ?? 'Appointment',
      scheduledFor: _parseDateTime(json['scheduled_for']),
      status: json['status'] as String? ?? '',
      reason: json['reason'] as String?,
      locationLabel: json['location_label'] as String?,
      adminNote: json['admin_note'] as String?,
      requestedByName: json['requested_by_name'] as String?,
      requestedByRole: json['requested_by_role'] as String?,
      proposedFor: _parseDateTime(json['proposed_for']),
      driverResponseNote: json['driver_response_note'] as String?,
      respondedAt: _parseDateTime(json['responded_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString();
  if (text.length >= 10) {
    return DateTime.tryParse(text.length == 10 ? '${text}T00:00:00' : text);
  }
  return DateTime.tryParse(text);
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
