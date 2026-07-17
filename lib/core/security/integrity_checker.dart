import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../l10n/localizations_loader.dart';
import 'screen_protector_service.dart';
import 'security_bypass_store.dart';
import 'security_event_repository.dart';
import 'security_event_types.dart';
import 'security_warning_dialog.dart';

class SecurityBlockedException implements Exception {
  SecurityBlockedException(this.message);
  final String message;

  @override
  String toString() => message;
}

class IntegrityChecker {
  IntegrityChecker({
    required SecurityEventRepository repository,
    required ScreenProtectorService screenProtectorService,
  }) : _repository = repository,
       _screenProtectorService = screenProtectorService;

  final SecurityEventRepository _repository;
  final ScreenProtectorService _screenProtectorService;

  DateTime? _lastDeveloperWarningAt;
  DateTime? _lastMockSettingWarningAt;
  DateTime? _lastMockLocationWarningAt;
  static const _warnCooldown = Duration(seconds: 30);

  Future<void> checkDeveloperMode({bool warn = true}) async {
    if (SecurityBypassStore.isEnabled) return;
    final enabled = await _screenProtectorService.isDeveloperModeEnabled();
    if (!enabled) return;
    await _repository.logEvent(type: SecurityEventType.developerMode);
    if (warn && _canWarn(_lastDeveloperWarningAt)) {
      _lastDeveloperWarningAt = DateTime.now();
      final l10n = await loadSavedLocalizations();
      unawaited(
        SecurityWarningDialog.show(
          title: l10n.developerModeDetectedTitle,
          message: l10n.developerModeDetectedMessage,
        ),
      );
    }
  }

  Future<void> checkMockLocationSetting({bool warn = true}) async {
    if (SecurityBypassStore.isEnabled) return;
    final enabled = await _screenProtectorService
        .isMockLocationSettingEnabled();
    if (!enabled) return;
    await _repository.logEvent(type: SecurityEventType.mockLocation);
    if (warn && _canWarn(_lastMockSettingWarningAt)) {
      _lastMockSettingWarningAt = DateTime.now();
      final l10n = await loadSavedLocalizations();
      unawaited(
        SecurityWarningDialog.show(
          title: l10n.mockLocationDetectedTitle,
          message: l10n.mockLocationDetectedMessage,
        ),
      );
    }
  }

  Future<void> assertTrustedPosition(
    Position position, {
    required String action,
    bool warn = true,
    bool throwOnMock = true,
  }) async {
    if (SecurityBypassStore.isEnabled) return;
    if (!position.isMocked) return;

    final context = <String, dynamic>{
      'action': action,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy_m': position.accuracy,
      'speed_mps': position.speed,
      'is_mocked': position.isMocked,
      'timestamp': position.timestamp.toIso8601String(),
    };
    await _repository.logEvent(
      type: SecurityEventType.mockLocation,
      severity: SecuritySeverity.warning,
      context: context,
    );
    await _repository.logEvent(
      type: SecurityEventType.mockLocationBlockedAction,
      severity: SecuritySeverity.blocked,
      context: context,
    );
    final l10n = await loadSavedLocalizations();
    if (warn && _canWarn(_lastMockLocationWarningAt)) {
      _lastMockLocationWarningAt = DateTime.now();
      unawaited(
        SecurityWarningDialog.show(
          title: l10n.fakeGpsDetectedTitle,
          message: l10n.fakeGpsDetectedMessage,
        ),
      );
    }
    if (throwOnMock) {
      throw SecurityBlockedException(l10n.fakeGpsBlockedAction);
    }
  }

  bool _canWarn(DateTime? at) {
    if (at == null) return true;
    return DateTime.now().difference(at) >= _warnCooldown;
  }
}
