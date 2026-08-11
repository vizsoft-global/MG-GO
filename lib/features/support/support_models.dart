class SupportRequestSummary {
  const SupportRequestSummary({
    required this.id,
    required this.requestCode,
    required this.requestType,
    required this.status,
    this.currentStepLabel,
    this.createdAt,
    this.amountKwd,
  });

  final String id;
  final String requestCode;
  final String requestType;
  final String status;
  final String? currentStepLabel;
  final DateTime? createdAt;
  final double? amountKwd;

  factory SupportRequestSummary.fromJson(Map<String, dynamic> json) {
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
