import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/rider_backend.dart';
import '../../l10n/app_localizations.dart';

/// One row of the rider's own conduct ledger.
///
/// Only the four driver-visible columns are exposed. `created_by` is a staff
/// identifier and `source` tells the rider nothing they can act on, so neither
/// is selected — see the column list in [wrongActionsProvider].
class RiderWrongAction {
  const RiderWrongAction({
    required this.id,
    required this.actionType,
    required this.severity,
    required this.details,
    required this.occurredAt,
  });

  final String id;
  final String actionType;
  final String severity;
  final String? details;
  final DateTime? occurredAt;

  factory RiderWrongAction.fromRow(Map<String, dynamic> row) {
    return RiderWrongAction(
      id: (row['id'] ?? '').toString(),
      actionType: (row['action_type'] ?? 'other').toString(),
      severity: (row['severity'] ?? 'low').toString(),
      details: _details(row['details']),
      occurredAt: _occurredAt(row['occurred_at']),
    );
  }

  static String? _details(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _occurredAt(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

/// Home for every rider-facing `wrong_actions` read.
///
/// The rider reads the same table the admin panel writes, filtered to their
/// own rows (`driver_id == uid`). There is deliberately no callable: one
/// would be a second access path to maintain for a single collection.
class RiderWrongActionsRepository {
  RiderWrongActionsRepository();

  /// Exactly the documented driver-visible columns, newest first.
  ///
  /// `penalty_kwd` is intentionally absent: it exists only in the page
  /// registry jsonb, so requesting it would fail the select with `42703`.
  static const selectedColumns = 'id, action_type, severity, details, occurred_at';

  /// [riderId] exists for tests; in the app it is always the Firebase uid.
  Future<List<RiderWrongAction>> listMine({String? riderId}) async {
    final id = riderId ?? FirebaseAuth.instance.currentUser?.uid;
    if (id == null) return const [];

    final snap = await riderFirestore()
        .collection('wrong_actions')
        .where('driver_id', isEqualTo: id)
        .get();

    final rows = snap.docs.map((doc) {
      final data = doc.data();
      return RiderWrongAction.fromRow({
        'id': data['id'] ?? doc.id,
        'action_type': data['action_type'],
        'severity': data['severity'],
        'details': data['details'],
        'occurred_at': data['occurred_at'],
      });
    }).toList();

    rows.sort((a, b) {
      final at = a.occurredAt;
      final bt = b.occurredAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return List<RiderWrongAction>.unmodifiable(rows);
  }
}

final wrongActionsRepositoryProvider = Provider<RiderWrongActionsRepository>(
  (ref) => RiderWrongActionsRepository(),
);

/// The rider's own conduct ledger. Empty until the administrator records one,
/// and empty for a rider whose session cannot be resolved.
final wrongActionsProvider =
    FutureProvider.autoDispose<List<RiderWrongAction>>((ref) async {
  return ref.watch(wrongActionsRepositoryProvider).listMine();
});

/// English/Arabic label for the `wrong_action_type` enum.
String wrongActionTypeLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'delay' => l10n.wrongActionTypeDelay,
    'zone_breach' => l10n.wrongActionTypeZoneBreach,
    'hygiene_failed' => l10n.wrongActionTypeHygiene,
    'uniform' => l10n.wrongActionTypeUniform,
    'other' => l10n.wrongActionTypeOther,
    _ => key,
  };
}

/// English/Arabic label for the `severity_level` enum.
String wrongActionSeverityLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'low' => l10n.wrongActionSeverityLow,
    'medium' => l10n.wrongActionSeverityMedium,
    'high' => l10n.wrongActionSeverityHigh,
    _ => key,
  };
}
