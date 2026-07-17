import 'package:flutter/services.dart';

class DutyLockChannel {
  DutyLockChannel._();

  static const _channel = MethodChannel('dpd_userapp/duty_overlay');

  static Future<bool> hasOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestOverlayPermission() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('requestOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> enableLock() async {
    try {
      await _channel.invokeMethod<void>('enableLock');
    } catch (_) {}
  }

  static Future<void> disableLock() async {
    try {
      await _channel.invokeMethod<void>('disableLock');
    } catch (_) {}
  }

  static Future<bool> isLocked() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLocked');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
