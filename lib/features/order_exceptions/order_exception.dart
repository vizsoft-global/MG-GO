import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/rider_backend.dart';
import '../../l10n/app_localizations.dart';

class OrderExceptionCounts {
  const OrderExceptionCounts({
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final int pending;
  final int approved;
  final int rejected;

  factory OrderExceptionCounts.fromMap(Map<String, dynamic>? map) {
    return OrderExceptionCounts(
      pending: _asInt(map?['pending']),
      approved: _asInt(map?['approved']),
      rejected: _asInt(map?['rejected']),
    );
  }
}

class OrderExceptionCase {
  const OrderExceptionCase({
    required this.id,
    required this.createdAt,
    required this.day,
    required this.kind,
    required this.source,
    required this.status,
    required this.orderId,
    required this.reason,
    required this.proofKeys,
    required this.reviewNote,
  });

  final String id;
  final DateTime? createdAt;
  final String? day;
  final String kind;
  final String source;
  final String status;
  final String orderId;
  final String reason;
  final List<String> proofKeys;
  final String? reviewNote;

  factory OrderExceptionCase.fromMap(Map<String, dynamic> map) {
    final note = map['review_note']?.toString().trim();
    final day = map['day']?.toString().trim();
    return OrderExceptionCase(
      id: (map['id'] ?? '').toString(),
      createdAt: _asDate(map['created_at']),
      day: day == null || day.isEmpty ? null : day,
      kind: (map['kind'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      orderId: (map['order_id'] ?? '').toString(),
      reason: (map['reason'] ?? '').toString(),
      proofKeys: _asStrings(map['proof_keys']),
      reviewNote: note == null || note.isEmpty ? null : note,
    );
  }
}

class OrderExceptionList {
  const OrderExceptionList({required this.rows, required this.counts});

  final List<OrderExceptionCase> rows;
  final OrderExceptionCounts counts;

  factory OrderExceptionList.fromMap(Map<String, dynamic> map) {
    final rawRows = map['rows'];
    final rawCounts = map['counts'];
    return OrderExceptionList(
      rows: [
        for (final item in rawRows is List ? rawRows : const [])
          if (item is Map)
            OrderExceptionCase.fromMap(Map<String, dynamic>.from(item)),
      ],
      counts: OrderExceptionCounts.fromMap(
        rawCounts is Map ? Map<String, dynamic>.from(rawCounts) : null,
      ),
    );
  }
}

final orderExceptionsProvider = FutureProvider<OrderExceptionList>((ref) async {
  return driverListMyOrderExceptions();
});

Future<OrderExceptionList> driverListMyOrderExceptions() async {
  final map = await callRiderFunction('driverListMyOrderExceptions', {});
  return OrderExceptionList.fromMap(map);
}

Future<String> driverSubmitOrderException({
  required String kind,
  required String source,
  required String orderId,
  required String reason,
  required List<String> proofKeys,
}) async {
  final map = await callRiderFunction('driverSubmitOrderException', {
    'kind': kind,
    'source': source,
    'orderId': orderId,
    'reason': reason,
    'proofKeys': proofKeys,
  });
  return (map['id'] ?? '').toString();
}

String orderExceptionFailureMessage(AppLocalizations l10n, String raw) {
  final code = _knownOrderExceptionCode(raw);
  return switch (code) {
    'reason_required' => l10n.orderExceptionErrorReasonRequired,
    'reason_too_long' => l10n.orderExceptionErrorReasonTooLong,
    'proof_required' => l10n.orderExceptionErrorProofRequired,
    'invalid_proof_keys' => l10n.orderExceptionErrorInvalidProof,
    'too_many_proofs' => l10n.orderExceptionErrorTooManyProofs,
    'invalid_order_id' => l10n.orderExceptionErrorInvalidOrderId,
    'daily_limit_reached' => l10n.orderExceptionErrorDailyLimit,
    'duplicate_exception' => l10n.orderExceptionErrorDuplicate,
    _ => l10n.orderExceptionFailed,
  };
}

String? _knownOrderExceptionCode(String raw) {
  final lower = raw.trim().toLowerCase();
  const codes = [
    'reason_required',
    'reason_too_long',
    'proof_required',
    'invalid_proof_keys',
    'too_many_proofs',
    'invalid_order_id',
    'daily_limit_reached',
    'duplicate_exception',
  ];
  for (final code in codes) {
    if (lower == code || lower.startsWith('$code:') || lower.startsWith('$code ')) {
      return code;
    }
  }
  return null;
}

String orderExceptionKindLabel(AppLocalizations l10n, String kind) {
  return switch (kind) {
    'rejected' => l10n.orderExceptionKindRejected,
    'cancelled' => l10n.orderExceptionKindCancelled,
    _ => kind,
  };
}

String orderExceptionSourceLabel(AppLocalizations l10n, String source) {
  return switch (source) {
    'driver_declined' => l10n.orderExceptionSourceDriver,
    'store_or_customer' => l10n.orderExceptionSourceStore,
    _ => source,
  };
}

String orderExceptionStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'pending' => l10n.orderExceptionPending,
    'approved' => l10n.orderExceptionApproved,
    'rejected' => l10n.orderExceptionRejected,
    _ => status,
  };
}

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

List<String> _asStrings(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) item.toString()];
}

DateTime? _asDate(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is int) {
    final millis = raw > 100000000000 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
  if (raw is Map) {
    final seconds = raw['_seconds'] ?? raw['seconds'];
    if (seconds is int) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    }
  }
  return null;
}
