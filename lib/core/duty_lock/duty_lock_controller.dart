import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/rider_auth_service.dart';
import '../../features/home/home_providers.dart';
import 'duty_lock_channel.dart';

final dutyLockControllerProvider = Provider<DutyLockController?>((ref) {
  ref.watch(currentSessionProvider);
  if (Supabase.instance.client.auth.currentSession == null) {
    return null;
  }
  final controller = DutyLockController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class DutyLockController {
  DutyLockController(this._ref) {
    _ref.listen(homeDashboardProvider, (previous, next) {
      if (next.isLoading && !next.hasValue) return;
      final curr = next.asData?.value;
      if (curr == null) return;
      final wasOnline = previous?.asData?.value.isOnlineOnDuty ?? false;
      final isOnline = curr.isOnlineOnDuty;
      if (isOnline && !wasOnline) {
        unawaited(enable());
      } else if (!isOnline && wasOnline) {
        unawaited(disable());
      } else if (isOnline) {
        unawaited(enable());
      }
    });

    unawaited(_bootstrap());
  }

  final Ref _ref;

  Future<void> _bootstrap() async {
    if (!Platform.isAndroid) return;
    final isOnline = _ref.read(homeDashboardProvider).value?.isOnlineOnDuty ?? false;
    if (isOnline) {
      await enable();
    }
  }

  Future<void> enable() async {
    if (!Platform.isAndroid) return;
    await DutyLockChannel.enableLock();
  }

  Future<void> disable() async {
    if (!Platform.isAndroid) return;
    await DutyLockChannel.disableLock();
  }

  void dispose() {
    if (Platform.isAndroid) {
      unawaited(DutyLockChannel.disableLock());
    }
  }
}
