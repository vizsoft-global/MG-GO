import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/offline/offline_repo.dart';
import '../../core/l10n/l10n.dart';
import '../../core/permissions/duty_permissions_service.dart';
import '../../core/permissions/duty_session_gate.dart';
import '../duty/duty_session_gate_provider.dart';
import '../duty/on_duty_permission_gate.dart';
import '../duty/widgets/duty_readiness_sheet.dart';
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

  if (action == OnDutyAction.addDelivery && current?.isOnDuty == true) {
    if (!context.mounted) return false;
    return ensureDutyPermissionsForOnDutySession(context);
  }

  if (shouldSkipShiftForGoOnDuty(
    isOnlineOnDuty: current?.isOnlineOnDuty == true,
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
  final wentIn = await _goInWithReadiness(context, ref);
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
    final retry = await _goInWithReadiness(context, ref);
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

Future<bool?> _goInWithReadiness(BuildContext context, WidgetRef ref) async {
  if (Platform.isAndroid && context.mounted) {
    if (ref.read(dutySessionGateProvider).permissionsReady) {
      return _applyOnDuty(ref, context);
    }
    return showDutyReadinessSheet(
      context,
      flow: DutyReadinessFlow.startDuty,
      onContinue: () => _applyOnDuty(ref, context),
    );
  }
  return _applyOnDuty(ref, context);
}

Future<bool> _applyOnDuty(WidgetRef ref, BuildContext context) async {
  if (Platform.isAndroid) {
    final report = await DutyPermissionsService().audit(context.l10n);
    if (!report.canStartDuty) return false;
  }
  await ref
      .read(homeDashboardProvider.notifier)
      .setDutyState(isOnDuty: true, isOnline: true);
  return ref.read(homeDashboardProvider).value?.isOnlineOnDuty ?? false;
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

