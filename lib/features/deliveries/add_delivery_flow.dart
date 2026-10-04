import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../shift/on_duty_gate.dart';
import 'active_delivery_provider.dart';
import 'delivery_models.dart';
import 'delivery_proximity_preview.dart';
import 'delivery_service.dart';

String finishDeliveryPath({
  required String deliveryId,
  required FinishOutcome outcome,
}) =>
    '/deliveries/finish/$deliveryId?outcome=${outcome.name}';

/// What the control the rider tapped promised them, before any state was read.
///
/// The label and the destination used to be derived separately — the label from
/// the `activeDeliveryProvider` snapshot the widget last built with, the
/// destination from `await activeDeliveryProvider.future` at tap time. When
/// those disagreed (a loading or errored provider falls back to "Pickup
/// Order", and the awaited read then resolves to a leftover active delivery)
/// a rider asking to log a pickup was handed the Mark as Delivered screen.
/// Naming the intent removes the disagreement: the button that says pickup
/// always goes to pickup, and a genuinely open order is *reported*, not
/// silently substituted.
enum DeliveryActionIntent {
  /// Pickup or finish, whichever applies. For callers that render no label.
  auto,

  /// "Pickup Order" / "Add Delivery" — start a new order.
  pickup,

  /// "Mark as Delivered" — continue the order already in progress.
  finish,
}

/// Server-confirmed in-progress order — never a persisted session id on its own.
///
/// The label above the button is allowed to be stale; the decision is not. On a
/// successful read the shared provider is invalidated so the next build agrees
/// with what the tap just acted on. On failure the cached value is returned,
/// and the phantom-session guard in `activeDeliveryProvider` is what keeps that
/// fallback honest.
Future<ActiveDelivery?> resolveActiveDeliveryForDecision(WidgetRef ref) async {
  final service = ref.read(deliveryServiceProvider);
  try {
    final active = await service.getActivePickup();
    await setActiveDeliverySession(
      active?.id,
      externalOrderId: active?.externalOrderId,
      pickupAt: active?.pickupAt,
    );
    ref.invalidate(activeDeliveryProvider);
    return active;
  } catch (_) {
    return ref.read(activeDeliveryProvider).value;
  }
}

void _openRoute(BuildContext context, String path, {required bool replace}) {
  if (replace) {
    context.go(path);
  } else {
    context.push(path);
  }
}

/// Tells the rider an order is already open instead of quietly opening the
/// finish screen under a button that said something else.
Future<void> _reportOpenOrder(
  BuildContext context,
  ActiveDelivery active, {
  required bool replace,
}) async {
  final l10n = context.l10n;
  final orderId = active.externalOrderId.trim();
  final openCurrent = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        orderId.isEmpty
            ? l10n.deliveryAlreadyInProgressTitle
            : l10n.deliveryAlreadyInProgressTitleWithOrder(orderId),
      ),
      content: Text(l10n.deliveryAlreadyInProgressBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.openCurrentOrder),
        ),
      ],
    ),
  );
  if (openCurrent != true || !context.mounted) return;
  _openRoute(context, '/deliveries/active', replace: replace);
}

/// Opens pickup or finish flow depending on whether a delivery is in progress.
Future<void> openDeliveryAction(
  BuildContext context,
  WidgetRef ref, {
  FinishOutcome? outcome,
  bool replace = false,
  DeliveryActionIntent intent = DeliveryActionIntent.auto,
}) async {
  final ok = await ensureOnDutyForAction(
    context,
    ref,
    action: OnDutyAction.addDelivery,
  );
  if (ok != true || !context.mounted) return;

  unawaited(ref.read(deliveryProximityPreviewProvider.notifier).warmUp());

  final active = await resolveActiveDeliveryForDecision(ref);
  if (!context.mounted) return;

  if (intent == DeliveryActionIntent.finish) {
    if (active == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.deliveryNoActiveOrder)),
      );
      return;
    }
    _openRoute(
      context,
      finishDeliveryPath(
        deliveryId: active.id,
        outcome: outcome ?? FinishOutcome.delivered,
      ),
      replace: replace,
    );
    return;
  }

  if (active != null) {
    if (intent == DeliveryActionIntent.pickup) {
      await _reportOpenOrder(context, active, replace: replace);
      return;
    }
    _openRoute(
      context,
      finishDeliveryPath(
        deliveryId: active.id,
        outcome: outcome ?? FinishOutcome.delivered,
      ),
      replace: replace,
    );
    return;
  }

  _openRoute(context, '/deliveries/add', replace: replace);
}

/// Legacy entry point — routes through [openDeliveryAction].
Future<void> openAddDelivery(
  BuildContext context,
  WidgetRef ref, {
  bool replace = false,
}) =>
    openDeliveryAction(
      context,
      ref,
      replace: replace,
      intent: DeliveryActionIntent.pickup,
    );

Future<void> openAddPickup(
  BuildContext context,
  WidgetRef ref, {
  bool replace = false,
}) =>
    openDeliveryAction(
      context,
      ref,
      replace: replace,
      intent: DeliveryActionIntent.pickup,
    );

Future<void> openFinishDelivery(
  BuildContext context,
  WidgetRef ref, {
  required String deliveryId,
  required FinishOutcome outcome,
  bool replace = false,
}) async {
  final ok = await ensureOnDutyForAction(
    context,
    ref,
    action: OnDutyAction.addDelivery,
  );
  if (ok != true || !context.mounted) return;

  final path = finishDeliveryPath(deliveryId: deliveryId, outcome: outcome);
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
