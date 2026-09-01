/// Display helpers for Request Details. Kept free of widgets so the fuel
/// amount / transfer-type / clarification-thread rules can be unit-tested.

String? moneyOrNull(dynamic value, String Function(dynamic) format) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  return format(value);
}

String? fuelTransferTypeLabel({
  required dynamic raw,
  required String cash,
  required String salary,
}) {
  switch (raw?.toString().trim().toLowerCase()) {
    case 'cash':
      return cash;
    case 'salary':
      return salary;
    default:
      return null;
  }
}

dynamic firstAmount(Map<String, dynamic> request, Map<String, dynamic> payload) {
  return request['amount_kwd'] ?? payload['amount_kwd'] ?? payload['amount'];
}

/// Every clarification, oldest first — not only the unanswered admin prompt.
List<Map<String, dynamic>> clarificationThread(
  List<Map<String, dynamic>> clarifications,
) {
  final copy = List<Map<String, dynamic>>.from(clarifications);
  copy.sort((a, b) {
    final da = DateTime.tryParse(a['asked_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final db = DateTime.tryParse(b['asked_at']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return da.compareTo(db);
  });
  return copy;
}

bool isAssetFirstTime(dynamic mode) {
  return RegExp(r'^\s*first\s*time\s*$', caseSensitive: false)
      .hasMatch(mode?.toString() ?? '');
}

bool hideAssetCurrentStatus(String fieldKey, dynamic requestMode) {
  return fieldKey == 'asset_current_status' && isAssetFirstTime(requestMode);
}

bool parseScreenshotRestricted(dynamic raw, {bool fallback = true}) {
  if (raw == null) return fallback;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  switch (raw.toString().trim().toLowerCase()) {
    case 'false':
    case '0':
    case 'no':
      return false;
    case 'true':
    case '1':
    case 'yes':
      return true;
    default:
      return fallback;
  }
}

class OnBehalfDetail {
  const OnBehalfDetail({this.byName, this.atIso});

  final String? byName;
  final String? atIso;

  bool get hasRows =>
      (byName != null && byName!.isNotEmpty) ||
      (atIso != null && atIso!.isNotEmpty);
}

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool looksLikeUuid(String? value) {
  final text = value?.trim() ?? '';
  return text.isNotEmpty && _uuidPattern.hasMatch(text);
}

/// Bookkeeping the rider must never see as a Request Details row.
const internalRequestPayloadKeys = {
  'demo_qa',
  'awaiting_driver_ack',
  'driver_ack_at',
  'driver_ack_note',
  'awaiting_driver_reschedule',
  'reschedule',
  'created_on_behalf',
  'created_on_behalf_by',
  'created_on_behalf_by_name',
  'created_on_behalf_at',
};

bool isInternalRequestPayloadKey(String key) =>
    internalRequestPayloadKeys.contains(key);

String humanizeFieldKey(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

/// Catalogue label wins; otherwise `salary_issues` becomes "Salary Issues".
String complaintCategoryLabel(
  String? key, {
  Map<String, String> labelsByKey = const {},
}) {
  final trimmed = key?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  return labelsByKey[trimmed] ?? humanizeFieldKey(trimmed);
}

OnBehalfDetail? onBehalfDetail(Map<String, dynamic> payload) {
  final flagged = payload['created_on_behalf'] == true ||
      payload['created_on_behalf']?.toString() == 'true';
  final rawName = payload['created_on_behalf_by_name']?.toString().trim();
  final byName =
      (rawName != null && rawName.isNotEmpty && !looksLikeUuid(rawName))
          ? rawName
          : null;
  final atIso = payload['created_on_behalf_at']?.toString().trim();
  if (!flagged && byName == null && (atIso == null || atIso.isEmpty)) {
    return null;
  }
  return OnBehalfDetail(
    byName: byName,
    atIso: (atIso != null && atIso.isNotEmpty) ? atIso : null,
  );
}

/// Payload leftover dump for types without handwritten rows.
/// Never prints `true`, a staff UUID, or an unformatted ISO timestamp.
List<MapEntry<String, String>> visiblePayloadEntries({
  required Map<String, dynamic> payload,
  Map<String, String> categoryLabels = const {},
  String Function(DateTime dt)? formatDateTime,
}) {
  final rows = <MapEntry<String, String>>[];
  payload.forEach((key, value) {
    if (isInternalRequestPayloadKey(key)) return;
    if (value == null || value is bool || value is Map || value is List) return;
    final raw = value.toString().trim();
    if (raw.isEmpty || looksLikeUuid(raw)) return;
    if (key == 'category') {
      rows.add(MapEntry(key, complaintCategoryLabel(raw, labelsByKey: categoryLabels)));
      return;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null && raw.contains('T') && formatDateTime != null) {
      rows.add(MapEntry(key, formatDateTime(parsed)));
      return;
    }
    rows.add(MapEntry(key, raw));
  });
  return rows;
}

/// Loan / asset / sick-leave terms stay on the detail after the rider
/// acknowledges. Hiding the card the moment `awaiting_driver_ack` clears is
/// why Deduction start date vanished after approve.
bool showAdminResponseCard({
  required String requestType,
  required String status,
  required bool awaitingAck,
}) {
  if (awaitingAck) return true;
  const termTypes = {'loan', 'asset', 'sick_leave'};
  if (termTypes.contains(requestType) &&
      (status == 'approved' || status == 'closed')) {
    return true;
  }
  const responseTypes = {'salary_justification', 'complaint'};
  return responseTypes.contains(requestType) &&
      (status == 'responded' || status == 'solved' || status == 'closed');
}

/// Step `meta` first, then payload — an older approve may have written only one.
String? loanDeductionStartDate({
  required Map<String, dynamic> meta,
  required Map<String, dynamic> payload,
}) {
  final fromMeta = meta['deduction_start_date']?.toString().trim();
  if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
  final fromPayload = payload['deduction_start_date']?.toString().trim();
  if (fromPayload != null && fromPayload.isNotEmpty) return fromPayload;
  return null;
}

bool clarificationHasContent(Map<String, dynamic> row) {
  final question = row['question']?.toString().trim() ?? '';
  final answer = row['answer']?.toString().trim() ?? '';
  return question.isNotEmpty || answer.isNotEmpty;
}
