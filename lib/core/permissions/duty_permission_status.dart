import '../../l10n/app_localizations.dart';

enum DutyPermissionKind {
  locationServices,
  fineLocation,
  backgroundLocation,
  notifications,
  batteryOptimization,
  overlay,
  camera,
}

enum DutyPermissionState { granted, denied, restricted, unknown }

class DutyPermissionItem {
  const DutyPermissionItem({
    required this.kind,
    required this.state,
    required this.requiredForDuty,
    required this.title,
    required this.description,
  });

  final DutyPermissionKind kind;
  final DutyPermissionState state;
  final bool requiredForDuty;
  final String title;
  final String description;

  bool get isOk => state == DutyPermissionState.granted;

  bool get needsSettings =>
      state == DutyPermissionState.restricted ||
      kind == DutyPermissionKind.locationServices ||
      kind == DutyPermissionKind.batteryOptimization ||
      kind == DutyPermissionKind.overlay;

  String fixActionLabel(AppLocalizations l10n) {
    if (isOk) return '';
    switch (kind) {
      case DutyPermissionKind.locationServices:
        return l10n.openLocationSettings;
      case DutyPermissionKind.batteryOptimization:
        return l10n.openBatterySettings;
      case DutyPermissionKind.overlay:
        return l10n.grantOverlayPermission;
      case DutyPermissionKind.backgroundLocation:
        return l10n.openAppSettings;
      case DutyPermissionKind.fineLocation:
      case DutyPermissionKind.notifications:
      case DutyPermissionKind.camera:
        return needsSettings ? l10n.openAppSettings : l10n.allow;
    }
  }
}

class DutyReadinessReport {
  const DutyReadinessReport({required this.items});

  final List<DutyPermissionItem> items;

  List<DutyPermissionItem> get requiredItems =>
      items.where((i) => i.requiredForDuty).toList(growable: false);

  int get requiredTotal => requiredItems.length;

  int get requiredOkCount =>
      requiredItems.where((i) => i.isOk).length;

  bool get canStartDuty {
    if (requiredItems.isEmpty) return true;
    return requiredItems.every((i) => i.isOk);
  }

  List<DutyPermissionItem> get actionRequired =>
      requiredItems.where((i) => !i.isOk).toList(growable: false);

  /// Required checks with failures first so the sheet matches the status banner.
  List<DutyPermissionItem> get displayItems {
    final sorted = requiredItems.toList(growable: true);
    sorted.sort((a, b) {
      if (a.isOk != b.isOk) {
        return a.isOk ? 1 : -1;
      }
      return 0;
    });
    return sorted;
  }
}
