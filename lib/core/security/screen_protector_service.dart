import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'security_event_types.dart';

typedef CaptureAttemptCallback = Future<void> Function(SecurityEventType type);
typedef CaptureStateCallback = void Function(bool isCaptured);

class ScreenProtectorService {
  ScreenProtectorService._();
  static final ScreenProtectorService instance = ScreenProtectorService._();
  factory ScreenProtectorService() => instance;

  static const MethodChannel _securityChannel = MethodChannel(
    'dpd_userapp/security',
  );
  static const EventChannel _eventsChannel = EventChannel(
    'dpd_userapp/security_events',
  );

  StreamSubscription<dynamic>? _eventsSub;
  bool _enabled = false;
  int _sensitiveSessionDepth = 0;
  CaptureAttemptCallback? _globalCallback;
  CaptureAttemptCallback? _sensitiveCallback;
  CaptureStateCallback? _captureStateCallback;

  Future<void> enable(CaptureAttemptCallback onCaptureAttempt) async {
    _globalCallback = onCaptureAttempt;
    if (_enabled) {
      _ensureEventSubscription();
      return;
    }
    _enabled = true;
    if (Platform.isAndroid) {
      await _securityChannel.invokeMethod<void>('setSecureEnabled', true);
    }
    _ensureEventSubscription();
  }

  Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    _globalCallback = null;
    if (_sensitiveSessionDepth == 0) {
      await _eventsSub?.cancel();
      _eventsSub = null;
      if (Platform.isAndroid) {
        await _securityChannel.invokeMethod<void>('setSecureEnabled', false);
      }
    }
  }

  /// Detail-scoped protection for screenshot-restricted notifications.
  Future<void> beginSensitiveSession({
    required CaptureAttemptCallback onCaptureAttempt,
    CaptureStateCallback? onCaptureStateChanged,
  }) async {
    _sensitiveSessionDepth += 1;
    _sensitiveCallback = onCaptureAttempt;
    _captureStateCallback = onCaptureStateChanged;
    if (Platform.isAndroid) {
      await _securityChannel.invokeMethod<void>('setSecureEnabled', true);
    }
    if (Platform.isIOS) {
      await _securityChannel.invokeMethod<void>(
        'setSensitiveProtectionEnabled',
        true,
      );
      final captured = await isScreenCaptured();
      onCaptureStateChanged?.call(captured);
    }
    _ensureEventSubscription();
  }

  Future<void> endSensitiveSession() async {
    if (_sensitiveSessionDepth == 0) return;
    _sensitiveSessionDepth -= 1;
    if (_sensitiveSessionDepth > 0) return;
    _sensitiveCallback = null;
    _captureStateCallback = null;
    if (Platform.isIOS) {
      await _securityChannel.invokeMethod<void>(
        'setSensitiveProtectionEnabled',
        false,
      );
    }
    if (!_enabled) {
      await _eventsSub?.cancel();
      _eventsSub = null;
      if (Platform.isAndroid) {
        await _securityChannel.invokeMethod<void>('setSecureEnabled', false);
      }
    }
  }

  Future<bool> isScreenCaptured() async {
    if (!Platform.isIOS) return false;
    final captured = await _securityChannel.invokeMethod<bool>(
      'isScreenCaptured',
    );
    return captured ?? false;
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

  void _ensureEventSubscription() {
    _eventsSub ??= _eventsChannel.receiveBroadcastStream().listen((raw) async {
      final text = raw?.toString();
      if (text == 'screen_captured') {
        _captureStateCallback?.call(true);
      } else if (text == 'screen_capture_ended') {
        _captureStateCallback?.call(false);
      }

      final type = _mapCaptureEvent(text);
      if (type == null) return;
      final sensitive = _sensitiveCallback;
      if (sensitive != null) {
        await sensitive(type);
      }
      final global = _globalCallback;
      if (global != null && _enabled) {
        if (sensitive != null &&
            (type == SecurityEventType.screenshotAttempt ||
                type == SecurityEventType.screenRecordAttempt)) {
          return;
        }
        await global(type);
      }
    });
  }

  SecurityEventType? _mapCaptureEvent(String? raw) {
    switch (raw) {
      case 'screenshot_attempt':
        return SecurityEventType.screenshotAttempt;
      case 'screen_record_attempt':
      case 'screen_captured':
        return SecurityEventType.screenRecordAttempt;
      default:
        return null;
    }
  }
}
