import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'support_models.dart';
import 'support_providers.dart';

/// RSup/28 — appointment request detail. Figma's Accept / Reject / Propose
/// time actions call the real `driver_respond_appointment` RPC (accept →
/// `accepted` + push to RSup/29 confirmed; reject → `rejected` with an
/// optional reason; propose → `reschedule_requested` with a new
/// date/time + optional note). Nothing here is gated — the backend now
/// supports all three decisions.
class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  bool _submitting = false;

  String _formatDateTime(DateTime? value) {
    if (value == null) return '—';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d · $h:$min';
  }

  Future<void> _accept() async {
    setState(() => _submitting = true);
    try {
      await ref.read(supportServiceProvider).respondAppointment(
            appointmentId: widget.appointmentId,
            action: 'accept',
          );
      ref.invalidate(driverAppointmentsProvider);
      if (mounted) {
        context.push('/profile/support/appointments/${widget.appointmentId}/confirmed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reject appointment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Let admin know why you cannot make it.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rejectedRed,
                  side: BorderSide(color: AppColors.rejectedRed.withValues(alpha: 0.4)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reject appointment'),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref.read(supportServiceProvider).respondAppointment(
            appointmentId: widget.appointmentId,
            action: 'reject',
            note: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
          );
      ref.invalidate(driverAppointmentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment rejected')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _proposeTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !mounted) return;
    final proposed = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    final ctrl = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: 20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Propose a new time',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              _formatDateTime(proposed),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Note for admin (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send proposed time'),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref.read(supportServiceProvider).respondAppointment(
            appointmentId: widget.appointmentId,
            action: 'propose',
            proposedFor: proposed,
            note: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
          );
      ref.invalidate(driverAppointmentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proposed time sent to admin')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            if (item.id == widget.appointmentId) {
              row = item;
              break;
            }
          }
          if (row == null) {
            return const Center(child: Text('Appointment not found'));
          }
          final appointment = row;
          final needsResponse =
              appointment.status == 'pending' || appointment.status == 'scheduled';
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
                                Text(
                                  '${appointment.appointmentCode} · From '
                                  '${appointment.requestedByName ?? 'admin'}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
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
                          if (appointment.proposedFor != null)
                            _DetailRow(
                              label: 'Your proposed time',
                              value: _formatDateTime(appointment.proposedFor),
                            ),
                          if (appointment.driverResponseNote != null &&
                              appointment.driverResponseNote!.trim().isNotEmpty)
                            _DetailRow(label: 'Your note', value: appointment.driverResponseNote!),
                          _DetailRow(label: 'Status', value: appointment.status),
                        ],
                      ),
                    ),
                    if (!needsResponse) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          switch (appointment.status) {
                            'accepted' => 'You accepted this appointment. Arrive on time at reception.',
                            'rejected' => 'You rejected this appointment.',
                            'reschedule_requested' =>
                              'You proposed a new time. Waiting for admin to confirm.',
                            _ => 'Your appointment is scheduled. Arrive on time at reception.',
                          },
                          style: const TextStyle(color: AppColors.primaryBlue, fontSize: 12.5),
                        ),
                      ),
                    ],
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
                                onPressed: _submitting ? null : _reject,
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _submitting ? null : _proposeTime,
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
                            onPressed: _submitting ? null : _accept,
                            child: _submitting
                                ? const SizedBox(
                                    height: 18, width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Accept appointment'),
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
