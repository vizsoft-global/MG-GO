import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/permissions/duty_session_gate.dart';
import '../duty/duty_session_gate_provider.dart';
import '../home/home_providers.dart';
import '../shift/on_duty_gate.dart';
import 'active_delivery_provider.dart';
import 'delivery_models.dart';
import 'delivery_proximity_preview.dart';

bool _isFullyClockedIn(WidgetRef ref) {
  final current = ref.read(homeDashboardProvider).value;
  if (current == null) return false;
  final sessionGate = ref.read(dutySessionGateProvider);
  return dutyToggleShowsIn(
    isOnline: current.isOnline,
    isOnDuty: current.isOnDuty,
    permissionsReady: sessionGate.permissionsReady,
    needsFreshClockIn: sessionGate.needsFreshClockIn,
    auditComplete: sessionGate.auditComplete,
  );
}

String _finishPath({
  required String deliveryId,
  required FinishOutcome outcome,
  required bool provisionalClockIn,
}) {
  final provisional = provisionalClockIn ? '&provisionalClockIn=1' : '';
  return '/deliveries/finish/$deliveryId?outcome=${outcome.name}$provisional';
}

/// Opens pickup or finish flow depending on whether a delivery is in progress.
Future<void> openDeliveryAction(
  BuildContext context,
  WidgetRef ref, {
  FinishOutcome? outcome,
  bool replace = false,
}) async {
  final wasFullyClockedIn = _isFullyClockedIn(ref);
  final ok = await ensureOnDutyForAction(
    context,
    ref,
    action: OnDutyAction.addDelivery,
  );
  if (ok != true || !context.mounted) return;
  final provisionalClockIn = !wasFullyClockedIn;

  unawaited(ref.read(deliveryProximityPreviewProvider.notifier).warmUp());

  ActiveDelivery? active;
  try {
    active = await ref.read(activeDeliveryProvider.future);
  } catch (_) {
    active = null;
  }
  if (!context.mounted) return;

  if (active != null) {
    final path = _finishPath(
      deliveryId: active.id,
      outcome: outcome ?? FinishOutcome.delivered,
      provisionalClockIn: provisionalClockIn,
    );
    if (replace) {
      context.go(path);
    } else {
      context.push(path);
    }
    return;
  }

  if (replace) {
    context.go('/deliveries/add');
  } else {
    context.push('/deliveries/add');
  }
}

/// Legacy entry point — routes through [openDeliveryAction].
Future<void> openAddDelivery(
  BuildContext context,
  WidgetRef ref, {
  bool replace = false,
}) => openDeliveryAction(context, ref, replace: replace);

Future<void> openAddPickup(
  BuildContext context,
  WidgetRef ref, {
  bool replace = false,
}) => openDeliveryAction(context, ref, replace: replace);

Future<void> openFinishDelivery(
  BuildContext context,
  WidgetRef ref, {
  required String deliveryId,
  required FinishOutcome outcome,
  bool replace = false,
}) async {
  final wasFullyClockedIn = _isFullyClockedIn(ref);
  final ok = await ensureOnDutyForAction(
    context,
    ref,
    action: OnDutyAction.addDelivery,
  );
  if (ok != true || !context.mounted) return;

  final path = _finishPath(
    deliveryId: deliveryId,
    outcome: outcome,
    provisionalClockIn: !wasFullyClockedIn,
  );
  if (replace) {
    context.go(path);
  } else {
    context.push(path);
  }
}

Future<void> openActiveDelivery(
  BuildContext context,
  WidgetRef ref, {
  bool replace = false,
}) async {
  final ok = await ensureOnDutyForAction(
    context,
    ref,
    action: OnDutyAction.addDelivery,
  );
  if (ok != true || !context.mounted) return;

  if (replace) {
    context.go('/deliveries/active');
  } else {
    context.push('/deliveries/active');
  }
}

/// Pops the pickup screen when an order is in progress; otherwise lands on home
/// so a stale `/deliveries/active` route under the stack cannot trap the user.
void popPickupScreen(BuildContext context, WidgetRef ref) {
  final active = ref.read(activeDeliveryProvider).value;
  if (active == null) {
    context.go('/home');
    return;
  }
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}
