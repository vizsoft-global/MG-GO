import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final rawOccurredAt = row['occurred_at'];
    return RiderWrongAction(
      id: (row['id'] ?? '').toString(),
      actionType: (row['action_type'] ?? 'other').toString(),
      severity: (row['severity'] ?? 'low').toString(),
      details: (row['details'] as String?)?.trim().isEmpty ?? true
          ? null
          : (row['details'] as String).trim(),
      occurredAt: rawOccurredAt is String
          ? DateTime.tryParse(rawOccurredAt)
          : null,
    );
  }
}

/// Home for every rider-facing `wrong_actions` read.
///
/// The rider reads the same table the admin panel writes, filtered by RLS to
/// their own rows (`driver_id = auth.uid()`) — the path the page registry has
/// documented since the module shipped. There is deliberately no RPC: one
/// would be a second access path to maintain for a single table.
class RiderWrongActionsRepository {
  RiderWrongActionsRepository(this._client);

  final SupabaseClient _client;

  /// Exactly the documented driver-visible columns, newest first.
  ///
  /// `penalty_kwd` is intentionally absent: it exists only in the page
  /// registry jsonb, so requesting it would fail the select with `42703`.
  static const selectedColumns = 'id, action_type, severity, details, occurred_at';

  /// [riderId] exists for tests; in the app it is always `auth.uid()`, which is
  /// the same value the RLS policy compares `driver_id` against.
  Future<List<RiderWrongAction>> listMine({String? riderId}) async {
    final id = riderId ?? _client.auth.currentUser?.id;
    if (id == null) return const [];

    final rows = await _client
        .from('wrong_actions')
        .select(selectedColumns)
        .eq('driver_id', id)
        .order('occurred_at', ascending: false);

    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(RiderWrongAction.fromRow)
        .toList(growable: false);
  }
}

final wrongActionsRepositoryProvider = Provider<RiderWrongActionsRepository>(
  (ref) => RiderWrongActionsRepository(Supabase.instance.client),
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
