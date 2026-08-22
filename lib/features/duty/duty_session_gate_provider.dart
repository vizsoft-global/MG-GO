import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/permissions/duty_session_gate.dart';

class DutySessionGateState {
  const DutySessionGateState({
    this.permissionsReady = false,
    this.needsFreshClockIn = false,
    this.auditComplete = false,
  });

  final bool permissionsReady;
  final bool needsFreshClockIn;
  final bool auditComplete;
}

final dutySessionGateProvider =
    NotifierProvider<DutySessionGate, DutySessionGateState>(
      DutySessionGate.new,
    );

class DutySessionGate extends Notifier<DutySessionGateState> {
  @override
  DutySessionGateState build() => const DutySessionGateState();

  void applyAudit({
    required bool isOnDuty,
    required bool permissionsReady,
  }) {
    state = DutySessionGateState(
      permissionsReady: permissionsReady,
      needsFreshClockIn:
          state.needsFreshClockIn ||
          shouldMarkNeedsFreshClockIn(
            isOnDuty: isOnDuty,
            permissionsReady: permissionsReady,
          ),
      auditComplete: true,
    );
  }

  void markClockInCompleted() {
    state = const DutySessionGateState(
      permissionsReady: true,
      needsFreshClockIn: false,
      auditComplete: true,
    );
  }

  void markNeedsFreshClockIn() {
    state = DutySessionGateState(
      permissionsReady: state.permissionsReady,
      needsFreshClockIn: true,
      auditComplete: state.auditComplete,
    );
  }
}
