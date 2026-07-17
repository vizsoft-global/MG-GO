import 'dart:io';

import 'package:flutter/services.dart';

/// Thin wrapper around the native `dpd_userapp/app_installer` MethodChannel
/// implemented in `MainActivity.kt`.
///
/// We previously used the `open_filex` package to launch Android's package
/// installer. Starting with `open_filex` 4.x that plugin refuses to open
/// files with the `application/vnd.android.package-archive` MIME type unless
/// the app holds the `MANAGE_EXTERNAL_STORAGE` permission — even when the
/// APK is in our own app-specific external cache. That caused the forced
/// update flow to silently fail with `permissionDenied` and re-download in
/// a loop without ever surfacing the system "Install this app?" prompt.
///
/// The native channel calls `FileProvider.getUriForFile` + `ACTION_VIEW`
/// directly, which only requires `REQUEST_INSTALL_PACKAGES` (already
/// granted) and the manifest `<queries>` entry for the APK MIME type
/// (added in build 12+).
class AppInstaller {
  AppInstaller._();

  static const _channel = MethodChannel('dpd_userapp/app_installer');

  /// Launches the Android system package installer for the APK at [apkPath].
  ///
  /// Throws [AppInstallerException] on failure. Note that the OS still shows
  /// its own confirmation prompt — silent install is impossible on stock
  /// Android for non-system apps.
  static Future<void> installApk(String apkPath) async {
    if (!Platform.isAndroid) {
      throw AppInstallerException(
        code: 'unsupported_platform',
        message: 'APK install is only supported on Android.',
      );
    }
    try {
      await _channel.invokeMethod<bool>('installApk', {'path': apkPath});
    } on PlatformException catch (e) {
      throw AppInstallerException(
        code: e.code,
        message: e.message ?? e.code,
      );
    }
  }
}

class AppInstallerException implements Exception {
  AppInstallerException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'AppInstallerException($code): $message';
}
