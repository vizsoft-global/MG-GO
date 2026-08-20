import 'dart:convert';

import '../../core/storage/order_proof_constraints.dart';

/// Wire format for `p_order_proof_url` / `p_delivery_proof_url` / `p_cancel_proof_url`.
///
/// One key stays a plain string so queued rows from older builds still submit.
/// Two or more keys are a JSON array. The server parser accepts both.
String? encodeProofPayload(Iterable<String> keys) {
  final cleaned = keys
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .take(OrderProofConstraints.maxCount)
      .toList(growable: false);
  if (cleaned.isEmpty) return null;
  if (cleaned.length == 1) return cleaned.first;
  return jsonEncode(cleaned);
}

List<String> decodeProofPayload(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return const [];
  if (trimmed.startsWith('[')) {
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is! List) return const [];
      return parsed
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .take(OrderProofConstraints.maxCount)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
  return [trimmed];
}
