import 'dart:async';

import 'package:flutter/foundation.dart';
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

  /// Native security channels exist only on mobile; web has no dart:io Platform.
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  StreamSubscription<dynamic>? _eventsSub;
  bool _enabled = false;
  int _sensitiveSessionDepth = 0;
  int _allowSessionDepth = 0;
  CaptureAttemptCallback? _globalCallback;
  CaptureAttemptCallback? _sensitiveCallback;
  CaptureStateCallback? _captureStateCallback;

  bool get isAllowScreenshotSessionActive => _allowSessionDepth > 0;

  Future<void> enable(CaptureAttemptCallback onCaptureAttempt) async {
    _globalCallback = onCaptureAttempt;
    _enabled = true;
    _ensureEventSubscription();
    await _syncSecureFlag();
  }

  Future<void> disable() async {
    if (!_enabled && _sensitiveSessionDepth == 0 && _allowSessionDepth == 0) {
      return;
    }
    _enabled = false;
    _globalCallback = null;
    await _syncSecureFlag();
    if (_sensitiveSessionDepth == 0 && _allowSessionDepth == 0) {
      await _eventsSub?.cancel();
      _eventsSub = null;
    }
  }

  /// Restricted notification detail: keep screenshots blocked + iOS detect/blur.
  Future<void> beginSensitiveSession({
    required CaptureAttemptCallback onCaptureAttempt,
    CaptureStateCallback? onCaptureStateChanged,
  }) async {
    _sensitiveSessionDepth += 1;
    _sensitiveCallback = onCaptureAttempt;
    _captureStateCallback = onCaptureStateChanged;
    if (_isIOS) {
      await _securityChannel.invokeMethod<void>(
        'setSensitiveProtectionEnabled',
        true,
      );
      final captured = await isScreenCaptured();
      onCaptureStateChanged?.call(captured);
    }
    _ensureEventSubscription();
    await _syncSecureFlag();
  }

  Future<void> endSensitiveSession() async {
    if (_sensitiveSessionDepth == 0) return;
    _sensitiveSessionDepth -= 1;
    if (_sensitiveSessionDepth > 0) return;
    _sensitiveCallback = null;
    _captureStateCallback = null;
    if (_isIOS) {
      await _securityChannel.invokeMethod<void>(
        'setSensitiveProtectionEnabled',
        false,
      );
    }
    await _syncSecureFlag();
    if (!_enabled && _allowSessionDepth == 0) {
      await _eventsSub?.cancel();
      _eventsSub = null;
    }
  }

  /// Force-OFF / unrestricted notification detail: temporarily allow screenshots.
  /// Restores global restriction when [endAllowScreenshotSession] is called.
  Future<void> beginAllowScreenshotSession() async {
    _allowSessionDepth += 1;
    await _syncSecureFlag();
  }

  Future<void> endAllowScreenshotSession() async {
    if (_allowSessionDepth == 0) return;
    _allowSessionDepth -= 1;
    if (_allowSessionDepth > 0) return;
    await _syncSecureFlag();
  }

  Future<bool> isScreenCaptured() async {
    if (!_isIOS) return false;
    final captured = await _securityChannel.invokeMethod<bool>(
      'isScreenCaptured',
    );
    return captured ?? false;
  }

  Future<bool> isDeveloperModeEnabled() async {
    if (!_isAndroid) return false;
    final enabled = await _securityChannel.invokeMethod<bool>(
      'isDeveloperModeEnabled',
    );
    return enabled ?? false;
  }

  Future<bool> isMockLocationSettingEnabled() async {
    if (!_isAndroid) return false;
    final enabled = await _securityChannel.invokeMethod<bool>(
      'isMockLocationSettingEnabled',
    );
    return enabled ?? false;
  }

  /// Effective FLAG_SECURE: on when global/sensitive wants it, off during allow.
  Future<void> _syncSecureFlag() async {
    if (!_isAndroid) return;
    final wantSecure =
        (_enabled || _sensitiveSessionDepth > 0) && _allowSessionDepth == 0;
    await _securityChannel.invokeMethod<void>('setSecureEnabled', wantSecure);
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

      // Temporary allow session: do not show global "capture blocked" UI.
      if (_allowSessionDepth > 0) return;

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
