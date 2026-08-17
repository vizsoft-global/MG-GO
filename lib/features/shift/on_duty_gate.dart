import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/offline_repo.dart';
import '../../core/l10n/l10n.dart';
import '../../l10n/app_localizations.dart';
import '../../core/permissions/duty_battery_exemption.dart';
import '../../core/permissions/duty_permissions_service.dart';
import '../../core/permissions/duty_session_gate.dart';
import '../duty/duty_session_gate_provider.dart';
import '../duty/on_duty_permission_gate.dart';
import '../duty/widgets/duty_readiness_sheet.dart';
import '../home/home_duty_errors.dart';
import '../home/home_models.dart';
import '../home/home_providers.dart';
import 'shift_models.dart';
import 'shift_providers.dart';
import 'widgets/shift_submission_sheet.dart';

enum OnDutyAction { toggleOff, goOnDuty, addDelivery }

Future<bool?> ensureOnDutyForAction(
  BuildContext context,
  WidgetRef ref, {
  required OnDutyAction action,
  HomeDashboard? dashboard,
}) async {
  final current = dashboard ?? ref.read(homeDashboardProvider).value;

  if (action == OnDutyAction.toggleOff) {
    if (current == null) return false;
    await ref
        .read(homeDashboardProvider.notifier)
        .setDutyState(isOnDuty: false, isOnline: false);
    return true;
  }

  final sessionGate = ref.read(dutySessionGateProvider);
  // Match the Home toggle: leftover server is_on_duty must not skip Clock In
  // when the UI still shows Out (fresh install / incomplete permissions).
  final fullyClockedIn = current != null &&
      dutyToggleShowsIn(
        isOnline: current.isOnline,
        isOnDuty: current.isOnDuty,
        permissionsReady: sessionGate.permissionsReady,
        needsFreshClockIn: sessionGate.needsFreshClockIn,
        auditComplete: sessionGate.auditComplete,
      );

  if (action == OnDutyAction.addDelivery && fullyClockedIn) {
    if (!context.mounted) return false;
    return ensureDutyPermissionsForOnDutySession(context);
  }

  if (shouldSkipShiftForGoOnDuty(
    isOnlineOnDuty: fullyClockedIn,
    needsFreshClockIn: sessionGate.needsFreshClockIn,
  )) {
    if (!context.mounted) return false;
    return ensureDutyPermissionsForOnDutySession(context);
  }

  var shift = await _loadActiveShift(ref);
  if (shouldPromptShiftOnClockIn(
    hasActiveShift: _hasActiveShift(shift),
    needsFreshClockIn: sessionGate.needsFreshClockIn,
  )) {
    if (!context.mounted) return null;
    shift = await _promptMandatoryShift(context, ref, shiftExpired: shift != null);
    if (!_hasActiveShift(shift) || !context.mounted) return null;
  }

  if (!context.mounted) return null;
  final wentIn = await _goInWithReadiness(
    context,
    ref,
    // Delivery / Mark as Delivered must show Clock In — never silent re-clock.
    requirePrompt: action == OnDutyAction.addDelivery,
  );
  if (wentIn == true) {
    ref.read(dutySessionGateProvider.notifier).markClockInCompleted();
    return true;
  }
  if (wentIn == null) return null;

  if (_lastDutyErrorIsShiftRequired(ref)) {
    await _clearShiftCache(ref);
    ref.read(todayShiftProvider.notifier).clearLocal();
    if (!context.mounted) return null;
    shift = await _promptMandatoryShift(context, ref, shiftExpired: true);
    if (!_hasActiveShift(shift)) return null;
    if (!context.mounted) return null;
    final retry = await _goInWithReadiness(
      context,
      ref,
      requirePrompt: action == OnDutyAction.addDelivery,
    );
    if (retry == true) {
      ref.read(dutySessionGateProvider.notifier).markClockInCompleted();
      return true;
    }
    if (retry == null) return null;
  }

  return false;
}

bool _hasActiveShift(DailyShift? shift) =>
    shift != null && shift.isActive;

Future<DailyShift?> _loadActiveShift(WidgetRef ref) async {
  await ref.read(todayShiftProvider.notifier).refresh();
  return ref.read(todayShiftProvider).value;
}

Future<DailyShift?> _promptMandatoryShift(
  BuildContext context,
  WidgetRef ref, {
  required bool shiftExpired,
}) async {
  final submitted = await showShiftSubmissionSheet(
    context,
    required: true,
    shiftExpired: shiftExpired,
  );
  if (!submitted) return null;
  return ref.read(todayShiftProvider).value;
}

Future<bool?> _goInWithReadiness(
  BuildContext context,
  WidgetRef ref, {
  bool requirePrompt = false,
}) async {
  if (Platform.isAndroid && context.mounted) {
    if (!requirePrompt &&
        ref.read(dutySessionGateProvider).permissionsReady) {
      return (await _applyOnDuty(ref, context)).started;
    }
    return showDutyReadinessSheet(
      context,
      flow: DutyReadinessFlow.startDuty,
      onContinue: () => _applyOnDuty(ref, context),
    );
  }

  if (requirePrompt && context.mounted) {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.startDuty),
        content: Text(l10n.mustBeOnDutyToAddDelivery),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.startDuty),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return null;
  }

  return (await _applyOnDuty(ref, context)).started;
}

Future<DutyStartResult> _applyOnDuty(
  WidgetRef ref,
  BuildContext context,
) async {
  final l10n = context.l10n;
  if (Platform.isAndroid) {
    final report = await DutyPermissionsService().audit(l10n);
    if (!report.canStartDuty) return const DutyStartResult.blocked();
  }
  await ref
      .read(homeDashboardProvider.notifier)
      .setDutyState(isOnDuty: true, isOnline: true);
  unawaited(batteryExemptionRequester.ensureStockBatteryExemption());
  return dutyStartResultFrom(
    ref,
    l10n,
    ref.read(homeDashboardProvider).value?.isOnlineOnDuty ?? false,
  );
}

/// Names the server's refusal behind a clock-in that did not take, so the
/// readiness sheet can say why instead of reopening on the same state.
///
/// A failure with no rejection attached is a device check or a dismissal — the
/// sheet already lists those, and inventing copy for them would repeat it.
DutyStartResult dutyStartResultFrom(
  WidgetRef ref,
  AppLocalizations l10n,
  bool? started,
) {
  if (started == true) return const DutyStartResult.started();
  final rejection = lastDutyRejection(ref.read(homeDashboardProvider).error);
  return rejection == null
      ? const DutyStartResult.blocked()
      : DutyStartResult.refused(dutyRejectionMessage(l10n, rejection));
}

bool _lastDutyErrorIsShiftRequired(WidgetRef ref) {
  final error = ref.read(homeDashboardProvider).error;
  if (error == null) return false;
  final msg = error.toString().toLowerCase();
  return msg.contains('shift_required') ||
      msg.contains('submit today') ||
      msg.contains('shift before');
}

Future<void> _clearShiftCache(WidgetRef ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId != null) {
    await ref.read(offlineRepoProvider).clearActiveShiftCache(userId);
  }
}

