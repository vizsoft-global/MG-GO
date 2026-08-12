import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'support_providers.dart';

enum _ActionKind { clarify, ack, reschedule, esign, appointment }

class _ActionItem {
  const _ActionItem({
    required this.kind,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.route,
    this.at,
  });

  final _ActionKind kind;
  final String code;
  final String title;
  final String subtitle;
  final String route;
  final DateTime? at;
}

/// RSup/23 — rider Action Required inbox. Mixes clarifications, ack-gated
/// requests, pending e-signatures and appointment requests needing a
/// response into a single sorted queue (Figma Notifications frame groups
/// the same categories under "Action needed").
class ActionRequiredScreen extends ConsumerWidget {
  const ActionRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final requests = ref.watch(myRequestsProvider);
    final esign = ref.watch(esignRequestsProvider);
    final appointments = ref.watch(driverAppointmentsProvider);

    final loading = requests.isLoading || esign.isLoading || appointments.isLoading;
    final anyError = requests.hasError ? requests.error : (esign.hasError ? esign.error : appointments.error);

    final items = <_ActionItem>[];
    for (final row in requests.asData?.value ?? const []) {
      if (row.status == 'needs_clarification') {
        items.add(_ActionItem(
          kind: _ActionKind.clarify,
          code: row.requestCode,
          title: l10n.supportReasonClarificationNeeded,
          subtitle: _requestTypeLabel(row.requestType, l10n),
          route: '/profile/support/requests/${row.id}',
          at: row.createdAt,
        ));
      } else if (row.awaitingReschedule) {
        items.add(_ActionItem(
          kind: _ActionKind.reschedule,
          code: row.requestCode,
          title: l10n.supportActionRescheduleProposed,
          subtitle: _requestTypeLabel(row.requestType, l10n),
          route: '/profile/support/requests/${row.id}',
          at: row.createdAt,
        ));
      } else if (row.awaitingDriverAck) {
        items.add(_ActionItem(
          kind: _ActionKind.ack,
          code: row.requestCode,
          title: l10n.supportActionAcknowledgeUpdate,
          subtitle: _requestTypeLabel(row.requestType, l10n),
          route: '/profile/support/requests/${row.id}',
          at: row.createdAt,
        ));
      }
    }
    for (final row in esign.asData?.value ?? const []) {
      if (row.isPending) {
        items.add(_ActionItem(
          kind: _ActionKind.esign,
          code: row.requestCode,
          title: l10n.supportActionDocumentToSign,
          subtitle: row.title,
          route: '/profile/support/sign/${row.id}',
          at: row.createdAt,
        ));
      }
    }
    // Appointment accept/reject/propose is BLOCKED — `appointment_status`
    // enum only has scheduled/completed/cancelled (no schema for driver
    // response), so appointments are surfaced via the Appointments tile
    // itself, not mixed into this action queue. See QA notes for RSup/28.

    items.sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.supportActionRequired),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile/support'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRequestsProvider);
          ref.invalidate(esignRequestsProvider);
          ref.invalidate(driverAppointmentsProvider);
          await Future.wait([
            ref.read(myRequestsProvider.future),
            ref.read(esignRequestsProvider.future),
            ref.read(driverAppointmentsProvider.future),
          ]);
        },
        child: loading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : anyError != null && items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(child: Text(l10n.supportCouldNotLoad('$anyError'))),
                    ],
                  )
                : items.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          Center(child: Text(l10n.supportNoActionRequired)),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Material(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              onTap: () => context.push(item.route),
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.underReviewAmber.withValues(alpha: 0.15),
                                child: Icon(_iconFor(item.kind),
                                    color: AppColors.underReviewAmber, size: 18),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text('${item.code} · ${item.subtitle}'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  static IconData _iconFor(_ActionKind kind) {
    return switch (kind) {
      _ActionKind.clarify => Icons.help_outline_rounded,
      _ActionKind.ack => Icons.notifications_active_outlined,
      _ActionKind.reschedule => Icons.event_repeat_outlined,
      _ActionKind.esign => Icons.draw_outlined,
      _ActionKind.appointment => Icons.event_note_outlined,
    };
  }

  static String _requestTypeLabel(String type, AppLocalizations l10n) {
    return switch (type) {
      'leave' => l10n.supportRequestTypeLeave,
      'sick_leave' => l10n.supportRequestTypeSickLeave,
      'asset' => l10n.supportRequestTypeAsset,
      'fuel' => l10n.supportRequestTypeFuel,
      'document' => l10n.supportRequestTypeDocument,
      'complaint' => l10n.supportRequestTypeComplaint,
      'salary_justification' => l10n.supportRequestTypeSalaryJustification,
      'loan' => l10n.supportRequestTypeLoanAdvance,
      _ => type,
    };
  }
}
