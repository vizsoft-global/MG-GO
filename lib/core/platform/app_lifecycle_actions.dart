import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppLifecycleActions {
  AppLifecycleActions._();

  static const MethodChannel _channel = MethodChannel(
    'dpd_userapp/app_lifecycle',
  );

  static Future<bool> moveTaskToBack() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final moved = await _channel.invokeMethod<bool>('moveTaskToBack');
      return moved ?? false;
    } on PlatformException {
      return false;
    }
  }
}
