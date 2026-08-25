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

bool clarificationHasContent(Map<String, dynamic> row) {
  final question = row['question']?.toString().trim() ?? '';
  final answer = row['answer']?.toString().trim() ?? '';
  return question.isNotEmpty || answer.isNotEmpty;
}
