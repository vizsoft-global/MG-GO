import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// RSup/28 — appointment request detail. Figma shows Accept / Reject /
/// Propose time actions, but `appointment_status` only has
/// scheduled/completed/cancelled (no driver-response columns) and there is
/// no `driver_respond_appointment` RPC. BLOCKED: buttons are shown for
/// layout parity but degrade honestly instead of faking success — see QA
/// notes for RSup/28–29.
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({required this.appointmentId, super.key});

  final String appointmentId;

  String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d · $h:$min';
  }

  void _notSupported(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$action isn\'t available yet — coming soon. This appointment is already on your schedule.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driverAppointmentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment request'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          DriverAppointment? row;
          for (final item in rows) {
            if (item.id == appointmentId) {
              row = item;
              break;
            }
          }
          if (row == null) {
            return const Center(child: Text('Appointment not found'));
          }
          final appointment = row;
          final needsResponse = appointment.status == 'scheduled';
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                            child: const Icon(Icons.event_note_outlined, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appointment.title,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${appointment.appointmentCode} · From admin',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          if (needsResponse)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.underReviewAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text('Action required',
                                  style: TextStyle(
                                      color: AppColors.underReviewAmber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Details', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (appointment.reason != null && appointment.reason!.trim().isNotEmpty)
                            _DetailRow(label: 'Purpose', value: appointment.reason!),
                          _DetailRow(label: 'Proposed date/time', value: _formatDateTime(appointment.scheduledFor)),
                          _DetailRow(label: 'Location', value: appointment.locationLabel ?? 'Central Tower'),
                          if (appointment.adminNote != null && appointment.adminNote!.trim().isNotEmpty)
                            _DetailRow(label: 'Note', value: appointment.adminNote!),
                          _DetailRow(label: 'Status', value: appointment.status),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        needsResponse
                            ? 'This is already on your schedule. Accept / reject / propose actions are coming soon.'
                            : 'Your appointment is scheduled. Arrive on time at reception.',
                        style: const TextStyle(color: AppColors.primaryBlue, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (needsResponse)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.rejectedRed,
                                  side: BorderSide(color: AppColors.rejectedRed.withValues(alpha: 0.4)),
                                ),
                                onPressed: () => _notSupported(context, 'Reject'),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _notSupported(context, 'Propose time'),
                                child: const Text('Propose time'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.blueberry),
                            onPressed: () => _notSupported(context, 'Accept appointment'),
                            child: const Text('Accept appointment'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
