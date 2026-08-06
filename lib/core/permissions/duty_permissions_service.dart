import 'dart:async';
import 'dart:io';

import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/duty_lock/duty_lock_channel.dart';
import '../../l10n/app_localizations.dart';
import 'duty_permission_status.dart';
import 'permission_request_gate.dart';

class DutyPermissionsService {
  static Future<T> _serializedRequest<T>(Future<T> Function() action) {
    return PermissionRequestGate.run(action);
  }
  Future<DutyReadinessReport> audit(AppLocalizations l10n) async {
    if (!Platform.isAndroid) {
      return const DutyReadinessReport(items: []);
    }

    final locationServices = await Geolocator.isLocationServiceEnabled();
    final geoPermission = await Geolocator.checkPermission();
    final fine = await Permission.location.status;
    final background = await Permission.locationAlways.status;
    final notifications = await Permission.notification.status;
    final camera = await Permission.camera.status;

    final batteryOk = await _isBatteryOptimizationDisabled();
    final overlayOk = await DutyLockChannel.hasOverlayPermission();

    final fineState = _mergeLocationState(
      _mapGeolocatorPermission(geoPermission, background: false),
      _mapStatus(fine),
    );
    final backgroundState = _mergeLocationState(
      _mapGeolocatorPermission(geoPermission, background: true),
      _mapStatus(background),
    );

    return DutyReadinessReport(
      items: [
        DutyPermissionItem(
          kind: DutyPermissionKind.locationServices,
          state: locationServices
              ? DutyPermissionState.granted
              : DutyPermissionState.denied,
          requiredForDuty: true,
          title: l10n.permissionLocationServicesTitle,
          description: l10n.permissionLocationServicesDesc,
        ),
        DutyPermissionItem(
          kind: DutyPermissionKind.fineLocation,
          state: fineState,
          requiredForDuty: true,
          title: l10n.permissionLocationAccessTitle,
          description: l10n.permissionLocationAccessDesc,
        ),
        DutyPermissionItem(
          kind: DutyPermissionKind.backgroundLocation,
          state: backgroundState,
          requiredForDuty: true,
          title: l10n.permissionBackgroundLocationTitle,
          description: l10n.permissionBackgroundLocationDesc,
        ),
        DutyPermissionItem(
          kind: DutyPermissionKind.notifications,
          state: _mapStatus(notifications),
          requiredForDuty: true,
          title: l10n.permissionNotificationsTitle,
          description: l10n.permissionNotificationsDesc,
        ),
        DutyPermissionItem(
          kind: DutyPermissionKind.batteryOptimization,
          state: batteryOk
              ? DutyPermissionState.granted
              : DutyPermissionState.denied,
          requiredForDuty: true,
          title: l10n.permissionBatteryOptimizationTitle,
          description: l10n.permissionBatteryOptimizationDesc,
        ),
        DutyPermissionItem(
          kind: DutyPermissionKind.overlay,
          state: overlayOk
              ? DutyPermissionState.granted
              : DutyPermissionState.denied,
          requiredForDuty: true,
          title: l10n.permissionOverlayTitle,
          description: l10n.permissionOverlayDesc,
        ),
        DutyPermissionItem(
          kind: DutyPermissionKind.camera,
          state: _mapStatus(camera),
          requiredForDuty: true,
          title: l10n.permissionCameraTitle,
          description: l10n.permissionCameraDesc,
        ),
      ],
    );
  }

  /// Opens the right system screen for the user to fix this check.
  Future<void> fix(DutyPermissionItem item) async {
    if (item.isOk) return;

    switch (item.kind) {
      case DutyPermissionKind.locationServices:
        await Geolocator.openLocationSettings();
        return;
      case DutyPermissionKind.batteryOptimization:
        await DisableBatteryOptimization
            .showDisableBatteryOptimizationSettings();
        return;
      case DutyPermissionKind.overlay:
        await DutyLockChannel.requestOverlayPermission();
        return;
      case DutyPermissionKind.backgroundLocation:
        final fine = await Permission.location.status;
        if (fine.isGranted) {
          await openAppSettings();
          return;
        }
        await _fixRuntimePermission(item);
        return;
      case DutyPermissionKind.fineLocation:
      case DutyPermissionKind.notifications:
      case DutyPermissionKind.camera:
        await _fixRuntimePermission(item);
        return;
    }
  }

  Future<void> _fixRuntimePermission(DutyPermissionItem item) async {
    if (item.state == DutyPermissionState.restricted) {
      await openSettings(item.kind);
      return;
    }

    final granted = await request(item.kind);
    if (granted) return;

    final permission = _permissionFor(item.kind);
    if (permission == null) {
      await openSettings(item.kind);
      return;
    }

    final status = await permission.status;
    if (status.isPermanentlyDenied || status.isDenied) {
      await openSettings(item.kind);
    }
  }

  Permission? _permissionFor(DutyPermissionKind kind) {
    switch (kind) {
      case DutyPermissionKind.fineLocation:
        return Permission.location;
      case DutyPermissionKind.backgroundLocation:
        return Permission.locationAlways;
      case DutyPermissionKind.notifications:
        return Permission.notification;
      case DutyPermissionKind.camera:
        return Permission.camera;
      case DutyPermissionKind.locationServices:
      case DutyPermissionKind.batteryOptimization:
      case DutyPermissionKind.overlay:
        return null;
    }
  }

  Future<bool> request(DutyPermissionKind kind) async {
    return _serializedRequest(() => _requestUnlocked(kind));
  }

  Future<bool> _requestUnlocked(DutyPermissionKind kind) async {
    switch (kind) {
      case DutyPermissionKind.locationServices:
        return Geolocator.openLocationSettings();
      case DutyPermissionKind.fineLocation:
        // Use permission_handler only — calling Geolocator.requestPermission()
        // immediately after stacks a second dialog and triggers
        // "request already running" on many OEM builds.
        return _requestPermission(Permission.location);
      case DutyPermissionKind.backgroundLocation:
        if (!await Permission.location.isGranted) {
          await _requestPermission(Permission.location);
        }
        return _requestPermission(Permission.locationAlways);
      case DutyPermissionKind.notifications:
        return _requestPermission(Permission.notification);
      case DutyPermissionKind.batteryOptimization:
        final opened =
            await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
        return opened ?? false;
      case DutyPermissionKind.overlay:
        await DutyLockChannel.requestOverlayPermission();
        return DutyLockChannel.hasOverlayPermission();
      case DutyPermissionKind.camera:
        return _requestPermission(Permission.camera);
    }
  }

  Future<bool> _requestPermission(Permission permission) async {
    try {
      final result = await permission.request();
      if (result.isGranted) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      return result.isGranted;
    } on PlatformException catch (e) {
      // Dialog dismissed or another request is still in flight — treat as denied.
      if (e.code == 'PermissionHandler.PermissionManager') return false;
      rethrow;
    }
  }

  Future<bool> openSettings(DutyPermissionKind kind) async {
    switch (kind) {
      case DutyPermissionKind.locationServices:
        return Geolocator.openLocationSettings();
      case DutyPermissionKind.batteryOptimization:
        final opened =
            await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
        return opened ?? false;
      case DutyPermissionKind.overlay:
        await DutyLockChannel.requestOverlayPermission();
        return DutyLockChannel.hasOverlayPermission();
      case DutyPermissionKind.fineLocation:
      case DutyPermissionKind.backgroundLocation:
      case DutyPermissionKind.notifications:
      case DutyPermissionKind.camera:
        return openAppSettings();
    }
  }

  DutyPermissionState _mapStatus(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return DutyPermissionState.granted;
    }
    if (status.isPermanentlyDenied) {
      return DutyPermissionState.restricted;
    }
    if (status.isDenied) {
      return DutyPermissionState.denied;
    }
    return DutyPermissionState.unknown;
  }

  DutyPermissionState _mapGeolocatorPermission(
    LocationPermission permission, {
    required bool background,
  }) {
    if (background) {
      if (permission == LocationPermission.always) {
        return DutyPermissionState.granted;
      }
      if (permission == LocationPermission.deniedForever) {
        return DutyPermissionState.restricted;
      }
      return DutyPermissionState.denied;
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return DutyPermissionState.granted;
    }
    if (permission == LocationPermission.deniedForever) {
      return DutyPermissionState.restricted;
    }
    return DutyPermissionState.denied;
  }

  /// Prefer the stricter of Geolocator vs permission_handler after App Info revokes.
  DutyPermissionState _mergeLocationState(
    DutyPermissionState primary,
    DutyPermissionState secondary,
  ) {
    if (primary == DutyPermissionState.granted &&
        secondary == DutyPermissionState.granted) {
      return DutyPermissionState.granted;
    }
    if (primary == DutyPermissionState.restricted ||
        secondary == DutyPermissionState.restricted) {
      return DutyPermissionState.restricted;
    }
    return DutyPermissionState.denied;
  }

  Future<bool> _isBatteryOptimizationDisabled() async {
    try {
      final disabled =
          await DisableBatteryOptimization.isBatteryOptimizationDisabled;
      if (disabled == true) return true;
      final manufacturer =
          await DisableBatteryOptimization.isManufacturerBatteryOptimizationDisabled;
      return manufacturer == true;
    } catch (_) {
      return false;
    }
  }
}
