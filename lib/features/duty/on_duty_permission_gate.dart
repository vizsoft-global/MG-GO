import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/permissions/duty_permission_prompt.dart';
import '../../core/permissions/duty_permissions_service.dart';
import 'widgets/duty_readiness_sheet.dart';

/// Shows the duty permission sheet when the rider is already on duty
/// (re-login / resume) and OS permissions were revoked.
class OnDutyPermissionGate extends StatefulWidget {
  const OnDutyPermissionGate({required this.isOnDuty, super.key});

  final bool isOnDuty;

  @override
  State<OnDutyPermissionGate> createState() => _OnDutyPermissionGateState();
}

class _OnDutyPermissionGateState extends State<OnDutyPermissionGate>
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
    if (!Platform.isAndroid) return;

    final report = await DutyPermissionsService().audit(context.l10n);
    if (!mounted) return;
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
      onContinue: () async => true,
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
