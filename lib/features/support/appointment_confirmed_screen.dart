import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_formatters.dart';
import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// RSup/29 — "Appointment confirmed". Reached after `driver_respond_appointment`
/// (action `accept`) succeeds on [AppointmentDetailScreen], which sets the
/// real `appointments.status = 'accepted'`. There is no device-calendar
/// integration in this app, so "View in calendar" opens the in-app
/// appointments list (the closest real equivalent) instead of a system
/// calendar it can't write to.
class AppointmentConfirmedScreen extends ConsumerWidget {
  const AppointmentConfirmedScreen({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(driverAppointmentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.apptConfirmedTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile/support/appointments'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          DriverAppointment? appointment;
          for (final item in rows) {
            if (item.id == appointmentId) {
              appointment = item;
              break;
            }
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 72,
                color: AppColors.progressGreen,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.apptConfirmedTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.apptConfirmedBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              if (appointment != null) _AppointmentSummaryCard(appointment: appointment),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/profile/support/appointments'),
                child: Text(l10n.apptDone),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go('/profile/support/appointments'),
                child: Text(l10n.apptViewInCalendar),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AppointmentSummaryCard extends StatelessWidget {
  const _AppointmentSummaryCard({required this.appointment});

  final DriverAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final when = appointment.scheduledFor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accentOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  when != null
                      ? monthShortNames(l10n)[when.month - 1].toUpperCase()
                      : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  when != null ? when.day.toString().padLeft(2, '0') : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when != null
                      ? l10n.apptTitleWithTime(
                          appointment.title,
                          DateFormat('HH:mm').format(when),
                        )
                      : appointment.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    appointment.locationLabel ?? l10n.visitCentralTower,
                    if (appointment.adminNote != null &&
                        appointment.adminNote!.trim().isNotEmpty)
                      appointment.adminNote!,
                  ].join(' — '),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
