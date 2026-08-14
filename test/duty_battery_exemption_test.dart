import 'dart:async';

import 'package:dpd_userapp/core/permissions/duty_battery_exemption.dart';
import 'package:dpd_userapp/core/permissions/duty_permission_status.dart';
import 'package:flutter_test/flutter_test.dart';

DutyPermissionItem _item({
  required DutyPermissionKind kind,
  required DutyPermissionState state,
  required bool requiredForDuty,
}) {
  return DutyPermissionItem(
    kind: kind,
    state: state,
    requiredForDuty: requiredForDuty,
    title: kind.name,
    description: kind.name,
  );
}

DutyReadinessReport _report({
  bool locationServicesOk = true,
  bool fineOk = true,
  bool backgroundOk = true,
  bool notificationsOk = true,
  bool overlayOk = true,
  bool cameraOk = true,
  bool stockBatteryOk = true,
  bool? oemRestricted,
}) {
  return DutyReadinessReport(
    items: [
      _item(
        kind: DutyPermissionKind.locationServices,
        state: locationServicesOk
            ? DutyPermissionState.granted
            : DutyPermissionState.denied,
        requiredForDuty: true,
      ),
      _item(
        kind: DutyPermissionKind.fineLocation,
        state: fineOk
            ? DutyPermissionState.granted
            : DutyPermissionState.denied,
        requiredForDuty: true,
      ),
      _item(
        kind: DutyPermissionKind.backgroundLocation,
        state: backgroundOk
            ? DutyPermissionState.granted
            : DutyPermissionState.denied,
        requiredForDuty: true,
      ),
      _item(
        kind: DutyPermissionKind.notifications,
        state: notificationsOk
            ? DutyPermissionState.granted
            : DutyPermissionState.denied,
        requiredForDuty: true,
      ),
      _item(
        kind: DutyPermissionKind.batteryOptimization,
        state: stockBatteryOk
            ? DutyPermissionState.granted
            : DutyPermissionState.denied,
        requiredForDuty: false,
      ),
      if (oemRestricted != null)
        _item(
          kind: DutyPermissionKind.oemBatteryOptimization,
          state: oemRestricted
              ? DutyPermissionState.denied
              : DutyPermissionState.granted,
          requiredForDuty: false,
        ),
      _item(
        kind: DutyPermissionKind.overlay,
        state: overlayOk
            ? DutyPermissionState.granted
            : DutyPermissionState.denied,
        requiredForDuty: true,
      ),
      _item(
        kind: DutyPermissionKind.camera,
        state: cameraOk
            ? DutyPermissionState.granted
            : DutyPermissionState.denied,
        requiredForDuty: true,
      ),
    ],
  );
}

void main() {
  group('interpretBatteryExemption', () {
    test('stock restricted is a warning and never clocks out', () {
      final snap = interpretBatteryExemption(
        stockDisabled: false,
        oemDisabled: null,
        oemCheckAvailable: false,
      );
      expect(snap.stockRestricted, isTrue);
      expect(snap.oemWarning, isFalse);
      expect(snap.shouldClockOut, isFalse);
    });

    test('stock allowed is not restricted', () {
      final snap = interpretBatteryExemption(
        stockDisabled: true,
        oemDisabled: null,
        oemCheckAvailable: false,
      );
      expect(snap.stockRestricted, isFalse);
      expect(snap.shouldClockOut, isFalse);
    });

    test('OEM restricted is a warning only when the check is reliable', () {
      final snap = interpretBatteryExemption(
        stockDisabled: true,
        oemDisabled: false,
        oemCheckAvailable: true,
      );
      expect(snap.stockRestricted, isFalse);
      expect(snap.oemWarning, isTrue);
      expect(snap.shouldClockOut, isFalse);
    });

    test('OEM unknown or unavailable never warns and never clocks out', () {
      expect(
        interpretBatteryExemption(
          stockDisabled: true,
          oemDisabled: null,
          oemCheckAvailable: false,
        ).oemWarning,
        isFalse,
      );
      expect(
        interpretBatteryExemption(
          stockDisabled: true,
          oemDisabled: false,
          oemCheckAvailable: false,
        ).oemWarning,
        isFalse,
      );
      final unknown = interpretBatteryExemption(
        stockDisabled: null,
        oemDisabled: null,
        oemCheckAvailable: false,
      );
      expect(unknown.stockRestricted, isTrue);
      expect(unknown.oemWarning, isFalse);
      expect(unknown.shouldClockOut, isFalse);
    });
  });

  group('shouldAutoRequestBatteryExemption', () {
    final now = DateTime.utc(2026, 8, 14, 10);

    test('requests when stock is restricted and there is no prior request', () {
      expect(
        shouldAutoRequestBatteryExemption(
          stockRestricted: true,
          lastRequestAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('keeps the 3-minute cooldown', () {
      expect(
        shouldAutoRequestBatteryExemption(
          stockRestricted: true,
          lastRequestAt: now.subtract(const Duration(minutes: 2, seconds: 59)),
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldAutoRequestBatteryExemption(
          stockRestricted: true,
          lastRequestAt: now.subtract(const Duration(minutes: 3)),
          now: now,
        ),
        isTrue,
      );
    });

    test('does not request when stock is already allowed', () {
      expect(
        shouldAutoRequestBatteryExemption(
          stockRestricted: false,
          lastRequestAt: null,
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('Go In gating', () {
    test('stock restricted does not block Go In when tracking prereqs are ok', () {
      final report = _report(stockBatteryOk: false);
      expect(report.canStartDuty, isTrue);
      expect(report.hasBatteryWarning, isTrue);
      expect(
        report.displayItems.any(
          (item) =>
              item.kind == DutyPermissionKind.batteryOptimization ||
              item.kind == DutyPermissionKind.oemBatteryOptimization,
        ),
        isFalse,
      );
    });

    test('OEM restricted or omitted never blocks Go In', () {
      final oem = _report(oemRestricted: true);
      expect(oem.canStartDuty, isTrue);
      expect(oem.hasBatteryWarning, isTrue);
      expect(_report().canStartDuty, isTrue);
      expect(_report().hasBatteryWarning, isFalse);
    });

    test('location services or location permission still block Go In', () {
      expect(_report(locationServicesOk: false).canStartDuty, isFalse);
      expect(_report(fineOk: false).canStartDuty, isFalse);
      expect(_report(backgroundOk: false).canStartDuty, isFalse);
    });

    test('deny / still restricted never signals clock-out', () {
      expect(
        interpretBatteryExemption(
          stockDisabled: false,
          oemDisabled: false,
          oemCheckAvailable: true,
        ).shouldClockOut,
        isFalse,
      );
    });
  });

  group('BatteryExemptionRequester', () {
    test('snapshot does not hang when stock or OEM never returns', () async {
      final requester = BatteryExemptionRequester(
        readStockDisabled: () => Completer<bool?>().future,
        readOemDisabled: () => Completer<bool?>().future,
        showStockDialog: () async => true,
        clock: () => DateTime.utc(2026, 8, 14, 10),
      );

      final snap = await requester.snapshot().timeout(
        batteryExemptionReadTimeout + const Duration(seconds: 2),
      );
      expect(snap.shouldClockOut, isFalse);
    });

    test('does not fire the dialog again inside the cooldown', () async {
      var dialogs = 0;
      var stockDisabled = false;
      final requester = BatteryExemptionRequester(
        readStockDisabled: () async => stockDisabled,
        readOemDisabled: () async => null,
        showStockDialog: () async {
          dialogs += 1;
          return true;
        },
        clock: () => DateTime.utc(2026, 8, 14, 10),
      );

      await requester.ensureStockBatteryExemption();
      await requester.ensureStockBatteryExemption();
      expect(dialogs, 1);
    });
  });
}
