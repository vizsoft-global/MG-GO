import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'security_event_types.dart';

typedef CaptureAttemptCallback = Future<void> Function(SecurityEventType type);

class ScreenProtectorService {
  static const MethodChannel _securityChannel = MethodChannel(
    'dpd_userapp/security',
  );
  static const EventChannel _eventsChannel = EventChannel(
    'dpd_userapp/security_events',
  );

  StreamSubscription<dynamic>? _eventsSub;
  bool _enabled = false;

  Future<void> enable(CaptureAttemptCallback onCaptureAttempt) async {
    if (_enabled) return;
    _enabled = true;
    if (Platform.isAndroid) {
      await _securityChannel.invokeMethod<void>('setSecureEnabled', true);
      _eventsSub = _eventsChannel.receiveBroadcastStream().listen((raw) async {
        final type = _mapCaptureEvent(raw?.toString());
        if (type != null) {
          await onCaptureAttempt(type);
        }
      });
    }
  }

  Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    await _eventsSub?.cancel();
    _eventsSub = null;
    if (Platform.isAndroid) {
      await _securityChannel.invokeMethod<void>('setSecureEnabled', false);
    }
  }

  Future<bool> isDeveloperModeEnabled() async {
    if (!Platform.isAndroid) return false;
    final enabled = await _securityChannel.invokeMethod<bool>(
      'isDeveloperModeEnabled',
    );
    return enabled ?? false;
  }

  Future<bool> isMockLocationSettingEnabled() async {
    if (!Platform.isAndroid) return false;
    final enabled = await _securityChannel.invokeMethod<bool>(
      'isMockLocationSettingEnabled',
    );
    return enabled ?? false;
  }

  SecurityEventType? _mapCaptureEvent(String? raw) {
    switch (raw) {
      case 'screenshot_attempt':
        return SecurityEventType.screenshotAttempt;
      case 'screen_record_attempt':
        return SecurityEventType.screenRecordAttempt;
      default:
        return null;
    }
  }
}
