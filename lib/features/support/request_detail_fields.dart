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

OnBehalfDetail? onBehalfDetail(Map<String, dynamic> payload) {
  final flagged = payload['created_on_behalf'] == true ||
      payload['created_on_behalf']?.toString() == 'true';
  final byName = payload['created_on_behalf_by_name']?.toString().trim();
  final atIso = payload['created_on_behalf_at']?.toString().trim();
  if (!flagged && (byName == null || byName.isEmpty) && (atIso == null || atIso.isEmpty)) {
    return null;
  }
  return OnBehalfDetail(
    byName: (byName != null && byName.isNotEmpty) ? byName : null,
    atIso: (atIso != null && atIso.isNotEmpty) ? atIso : null,
  );
}

bool clarificationHasContent(Map<String, dynamic> row) {
  final question = row['question']?.toString().trim() ?? '';
  final answer = row['answer']?.toString().trim() ?? '';
  return question.isNotEmpty || answer.isNotEmpty;
}
