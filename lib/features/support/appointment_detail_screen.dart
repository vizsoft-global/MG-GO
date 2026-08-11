import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driverAppointmentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment'),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (appointment.isUpcoming) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.progressGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.progressGreen.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.progressGreen),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your appointment is scheduled. Arrive on time at reception.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                appointment.appointmentCode,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                appointment.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'When',
                value: _formatDateTime(appointment.scheduledFor),
              ),
              _DetailRow(
                label: 'Location',
                value: appointment.locationLabel ?? 'Central Tower',
              ),
              _DetailRow(label: 'Status', value: appointment.status),
              if (appointment.reason != null &&
                  appointment.reason!.trim().isNotEmpty)
                _DetailRow(label: 'Reason', value: appointment.reason!),
              if (appointment.adminNote != null &&
                  appointment.adminNote!.trim().isNotEmpty)
                _DetailRow(label: 'Note', value: appointment.adminNote!),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go('/profile/support/appointments'),
                child: const Text('Back to appointments'),
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
            width: 88,
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
