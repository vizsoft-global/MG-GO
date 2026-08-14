import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/permissions/duty_permission_prompt.dart';
import '../../core/permissions/duty_permissions_service.dart';
import 'duty_session_gate_provider.dart';
import 'widgets/duty_readiness_sheet.dart';

/// Shows the duty permission sheet when the rider is already on duty
/// (re-login / resume) and OS permissions were revoked.
class OnDutyPermissionGate extends ConsumerStatefulWidget {
  const OnDutyPermissionGate({
    required this.isOnDuty,
    this.onCompleteFreshClockIn,
    super.key,
  });

  final bool isOnDuty;
  final Future<bool> Function()? onCompleteFreshClockIn;

  @override
  ConsumerState<OnDutyPermissionGate> createState() =>
      _OnDutyPermissionGateState();
}

class _OnDutyPermissionGateState extends ConsumerState<OnDutyPermissionGate>
    with WidgetsBindingObserver {
  bool _open = false;
  bool _dismissedThisForeground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybePrompt());
    });
  }

  @override
  void didUpdateWidget(covariant OnDutyPermissionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOnDuty && !oldWidget.isOnDuty) {
      _dismissedThisForeground = false;
      unawaited(_maybePrompt());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dismissedThisForeground = false;
      unawaited(_maybePrompt());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _maybePrompt() async {
    if (!mounted || !widget.isOnDuty || _open) return;
    if (!Platform.isAndroid) {
      ref.read(dutySessionGateProvider.notifier).applyAudit(
            isOnDuty: widget.isOnDuty,
            permissionsReady: true,
          );
      return;
    }

    final report = await DutyPermissionsService().audit(context.l10n);
    if (!mounted) return;
    ref.read(dutySessionGateProvider.notifier).applyAudit(
          isOnDuty: widget.isOnDuty,
          permissionsReady: report.canStartDuty,
        );
    if (!shouldPromptDutyPermissions(
      isOnDuty: widget.isOnDuty,
      permissionsReady: report.canStartDuty,
      promptAlreadyOpen: _open,
      dismissedThisForeground: _dismissedThisForeground,
    )) {
      return;
    }

    _open = true;
    final result = await showDutyReadinessSheet(
      context,
      flow: DutyReadinessFlow.goOnline,
      onContinue: () async {
        if (!mounted) return false;
        ref.read(dutySessionGateProvider.notifier).applyAudit(
              isOnDuty: widget.isOnDuty,
              permissionsReady: true,
            );
        if (!ref.read(dutySessionGateProvider).needsFreshClockIn) {
          return true;
        }
        final complete = widget.onCompleteFreshClockIn;
        if (complete == null) return true;
        return complete();
      },
    );
    _open = false;
    if (result != true) {
      _dismissedThisForeground = true;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Re-checks OS permissions for an already clocked-in session.
///
/// Returns true when ready, false/null when the rider dismisses without granting.
Future<bool?> ensureDutyPermissionsForOnDutySession(
  BuildContext context,
) async {
  if (!Platform.isAndroid) return true;
  if (!context.mounted) return false;

  final report = await DutyPermissionsService().audit(context.l10n);
  if (report.canStartDuty) return true;
  if (!context.mounted) return false;

  return showDutyReadinessSheet(
    context,
    flow: DutyReadinessFlow.goOnline,
    onContinue: () async => true,
  );
}
