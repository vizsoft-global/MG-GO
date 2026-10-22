import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/offline/offline_repo.dart';
import '../../core/l10n/l10n.dart';
import '../../l10n/app_localizations.dart';
import '../../core/permissions/duty_battery_exemption.dart';
import '../../core/permissions/duty_permissions_service.dart';
import '../../core/permissions/duty_session_gate.dart';
import '../../core/geo/device_location_resolver.dart';
import '../../core/storage/driver_upload_messages.dart';
import '../../core/storage/driver_upload_provider.dart';
import '../../core/storage/driver_upload_service.dart';
import '../duty/check_in_context.dart';
import '../duty/check_in_photo_capture.dart';
import '../duty/duty_session_gate_provider.dart';
import '../profile/avatar_picker_errors.dart';
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

  // Load the shift *before* deciding to skip. The duty flags alone can be a
  // stale "In" (offline cache, or a window that already ended), and skipping
  // here would send the rider on duty with no shift for the new day.
  var shift = await _loadActiveShift(ref);

  if (shouldSkipShiftForGoOnDuty(
    isOnlineOnDuty: fullyClockedIn,
    needsFreshClockIn: sessionGate.needsFreshClockIn,
    hasActiveShift: _hasActiveShift(shift),
  )) {
    if (!context.mounted) return false;
    return ensureDutyPermissionsForOnDutySession(context);
  }

  if (shouldPromptShiftOnClockIn(
    hasActiveShift: _hasActiveShift(shift),
    needsFreshClockIn: sessionGate.needsFreshClockIn,
  )) {
    if (!context.mounted) return null;
    shift = await _promptMandatoryShift(
      context,
      ref,
      shiftExpired: shift != null,
      initial: shift,
    );
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
    shift = await _promptMandatoryShift(
      context,
      ref,
      shiftExpired: true,
      initial: shift,
    );
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
  final previous = ref.read(todayShiftProvider).value;
  await ref.read(todayShiftProvider.notifier).refresh();
  return keepActiveShiftIfFetchMissed(
    fetched: ref.read(todayShiftProvider).value,
    previous: previous,
  );
}

Future<DailyShift?> _promptMandatoryShift(
  BuildContext context,
  WidgetRef ref, {
  required bool shiftExpired,
  DailyShift? initial,
}) async {
  final submitted = await showShiftSubmissionSheet(
    context,
    required: true,
    shiftExpired: shiftExpired,
    initial: initial,
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
      progressLabel: context.l10n.checkInCheckingRange,
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

  final alreadyOnDuty = ref.read(homeDashboardProvider).value?.isOnDuty == true;
  if (alreadyOnDuty) {
    return _writeDutyState(ref, l10n);
  }

  // 1. GPS first. Opening the camera before the server's proximity gate is what
  //    made an out-of-range rider spend a selfie and an upload to be told, after
  //    the fact, that they were 800 m from their restaurant.
  double? latitude;
  double? longitude;
  try {
    final position = await DeviceLocationResolver.instance.resolve(
      highAccuracy: true,
    );
    latitude = position.latitude;
    longitude = position.longitude;
  } catch (_) {
    return DutyStartResult.refused(l10n.checkInLocationUnavailable);
  }

  // 2. The precheck. A same-day repeat (clocked out, back in today) owes no
  //    check-in at all, so it skips both the camera and the range gate.
  CheckInContext? checkInContext;
  try {
    checkInContext = await ref
        .read(checkInContextServiceProvider)
        .load(latitude: latitude, longitude: longitude);
  } catch (_) {
    // Offline, or an answer we cannot use: keep the legacy order below so an
    // unreachable precheck never blocks clock-in — the write still validates.
    checkInContext = null;
  }

  switch (decideCheckInStep(checkInContext)) {
    case CheckInStep.skipCheckIn:
      return _writeDutyState(ref, l10n);
    case CheckInStep.skipPhoto:
      // The server answered `photo_required: false` (the safety toggle is off),
      // so write straight away. The location gate is still re-checked server
      // side, so a tampered client cannot clock in from outside.
      return _writeDutyState(
        ref,
        l10n,
        latitude: latitude,
        longitude: longitude,
      );
    case CheckInStep.blocked:
      return DutyStartResult.refused(
        checkInBlockedMessage(l10n, checkInContext!),
      );
    case CheckInStep.capturePhoto:
    case CheckInStep.fallback:
      break;
  }

  // 3. Only an in-range (or unknown) rider reaches the camera.
  String? checkInPhotoKey;
  try {
    if (!context.mounted) return const DutyStartResult.blocked();
    final photo = await captureCheckInPhoto(
      context,
      // A zone-gated rider has no restaurant; name the zone so the prompt still
      // reads "You are inside {name}" instead of a blank.
      restaurantName:
          checkInContext?.restaurant?.name ?? checkInContext?.zone?.name,
    );
    if (photo == null) return const DutyStartResult.blocked();
    final bytes = await photo.readAsBytes();
    final uploaded = await ref
        .read(driverUploadServiceProvider)
        .uploadCheckInPhoto(
          bytes: bytes,
          contentType: photo.mimeType ?? 'image/jpeg',
          filename: photo.name.isNotEmpty ? photo.name : 'check-in.jpg',
        );
    checkInPhotoKey = uploaded.objectKey;
  } on CameraPermissionDenied catch (error) {
    final message = userMessageIfCameraPermissionDenied(error, l10n);
    return DutyStartResult.refused(message ?? l10n.checkInPhotoFailed);
  } on DriverUploadException catch (error) {
    return DutyStartResult.refused(
      messageForDriverUploadException(error, l10n),
    );
  } catch (_) {
    return DutyStartResult.refused(l10n.checkInPhotoFailed);
  }

  return _writeDutyState(
    ref,
    l10n,
    checkInPhotoKey: checkInPhotoKey,
    latitude: latitude,
    longitude: longitude,
    restaurantId: checkInContext?.restaurant?.id,
  );
}

/// The duty write itself. The precheck never bypasses it: the server re-runs
/// the range gate, so a changed client still cannot clock in from anywhere.
Future<DutyStartResult> _writeDutyState(
  WidgetRef ref,
  AppLocalizations l10n, {
  String? checkInPhotoKey,
  double? latitude,
  double? longitude,
  String? restaurantId,
}) async {
  await ref.read(homeDashboardProvider.notifier).setDutyState(
        isOnDuty: true,
        isOnline: true,
        checkInPhotoKey: checkInPhotoKey,
        latitude: latitude,
        longitude: longitude,
        restaurantId: restaurantId,
      );
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
  final rejection = lastDutyRejection(ref.read(homeDashboardProvider).error);
  switch (decideDutyStartKind(
    started: started == true,
    rejection: rejection,
  )) {
    case DutyStartKind.refused:
      return DutyStartResult.refused(
        dutyRejectionMessage(
          l10n,
          rejection!,
          detail: lastDutyRefusalDetail(ref.read(homeDashboardProvider).error),
        ),
      );
    case DutyStartKind.started:
      return const DutyStartResult.started();
    case DutyStartKind.blocked:
      return const DutyStartResult.blocked();
  }
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
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId != null) {
    await ref.read(offlineRepoProvider).clearActiveShiftCache(userId);
  }
}

