import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo/device_location_resolver.dart';
import '../../core/settings/live_db_refresh.dart';
import 'delivery_proximity_service.dart';
import 'delivery_service.dart';

class DeliveryProximityPreviewState {
  const DeliveryProximityPreviewState({
    this.context,
    this.status,
    this.message,
    this.initialized = false,
    this.evaluating = false,
  });

  final DeliveryProximityContext? context;
  final DeliveryProximityStatus? status;
  final String? message;
  final bool initialized;
  final bool evaluating;

  bool get canSubmitDelivery => initialized && (status?.allowed ?? false);

  DeliveryProximityPreviewState copyWith({
    DeliveryProximityContext? context,
    DeliveryProximityStatus? status,
    String? message,
    bool? initialized,
    bool? evaluating,
    bool clearMessage = false,
  }) {
    return DeliveryProximityPreviewState(
      context: context ?? this.context,
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      initialized: initialized ?? this.initialized,
      evaluating: evaluating ?? this.evaluating,
    );
  }
}

final deliveryProximityPreviewProvider =
    NotifierProvider<
      DeliveryProximityPreviewNotifier,
      DeliveryProximityPreviewState
    >(DeliveryProximityPreviewNotifier.new);

class DeliveryProximityPreviewNotifier
    extends Notifier<DeliveryProximityPreviewState> {
  @override
  DeliveryProximityPreviewState build() {
    ref.listen(deliveryProximityContextProvider, (previous, next) {
      next.whenData((ctx) {
        if (previous?.value == ctx) return;
        // stateOrNull: safe during rebuild races; plain `state` can throw.
        unawaited(
          reevaluate(ctx, showLoading: stateOrNull?.initialized != true),
        );
      });
    });

    // Also re-evaluate on every coordinator tick (~5s) so that even if the
    // proximity context DTO is reference-equal (admin only nudged a value that
    // didn't change our resolved set, or the driver has merely moved), the
    // banner reflects the latest state quickly instead of waiting for the
    // 30s screen-local timer.
    final coordinator = ref.watch(liveDbRefreshCoordinatorProvider);
    void onCoordinatorTick() {
      final ctx = ref.read(deliveryProximityContextProvider).value;
      if (ctx != null) {
        unawaited(reevaluate(ctx, showLoading: false));
      }
    }

    coordinator.addListener(onCoordinatorTick);
    ref.onDispose(() => coordinator.removeListener(onCoordinatorTick));

    final ctx = ref.watch(deliveryProximityContextProvider).value;
    // Never read `state` before build() returns — Riverpod throws and poisons
    // this provider (grey ErrorWidget on Add Delivery after cache-warm relaunch).
    if (ctx != null && stateOrNull?.initialized != true) {
      Future.microtask(() => reevaluate(ctx, showLoading: false));
    }

    return const DeliveryProximityPreviewState();
  }

  /// Preload zone/restaurant rules + a fast GPS sample (e.g. before opening Add Delivery).
  Future<void> warmUp() async {
    try {
      await ref.read(deliveryProximityContextProvider.future);
    } catch (_) {}

    final ctx = ref.read(deliveryProximityContextProvider).value;
    if (ctx != null) {
      await reevaluate(ctx, showLoading: false);
    }
  }

  Future<void> reevaluate(
    DeliveryProximityContext contextData, {
    required bool showLoading,
  }) async {
    if (!contextData.proximityEnabled) {
      state = state.copyWith(
        context: contextData,
        status: DeliveryProximityStatus.proximityDisabled(),
        clearMessage: true,
        initialized: true,
        evaluating: false,
      );
      return;
    }

    if (showLoading && !state.initialized) {
      state = state.copyWith(context: contextData, evaluating: true);
    } else {
      state = state.copyWith(context: contextData);
    }

    try {
      final position = await DeviceLocationResolver.instance.resolve(
        requestIfDenied: false,
      );
      final status = ref
          .read(deliveryProximityServiceProvider)
          .evaluate(
            context: contextData,
            latitude: position.latitude,
            longitude: position.longitude,
          );
      state = state.copyWith(
        context: contextData,
        status: status,
        initialized: true,
        evaluating: false,
      );
    } on DeliveryServiceException catch (_) {
      state = state.copyWith(
        context: contextData,
        status: const DeliveryProximityStatus(
          allowed: false,
          reason: DeliveryProximityBlockReason.locationUnavailable,
        ),
        initialized: true,
        evaluating: false,
      );
    }
  }
}
