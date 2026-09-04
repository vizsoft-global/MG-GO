import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Play Store listing for the driver app. `market://` opens the Play app
/// directly; the https form is the fallback for phones without it.
const kDriverAppPlayPackage = 'com.musallam_delivery.app';
const kDriverAppPlayMarketUri =
    'market://details?id=$kDriverAppPlayPackage';
const kDriverAppPlayWebUri =
    'https://play.google.com/store/apps/details?id=$kDriverAppPlayPackage';

/// Decides whether the admin force-update gate blocks this install.
///
/// Mirrors the server rule in `driver-passcode-login`: an install that cannot
/// report its own `versionCode` is treated as below any minimum, because the
/// only builds that fail to report it predate the gate entirely. Both sides
/// have to agree, or a rider could pass the router and then be refused at
/// login with no screen that explains why.
bool forceUpdateBlocks({
  required bool forceUpdate,
  required int? minVersionCode,
  required int? installedVersionCode,
}) {
  if (!forceUpdate) return false;
  if (minVersionCode == null) return false;
  if (installedVersionCode == null) return true;
  return installedVersionCode < minVersionCode;
}

/// The build this process is running as, read once at startup so the router's
/// synchronous `redirect` can compare it against `app_settings`.
class InstalledBuild {
  InstalledBuild._();

  static int? _versionCode;
  static String? _versionName;
  static bool _loaded = false;

  /// `versionCode` from `pubspec.yaml` (`1.1.20+82` → 82). `null` when the
  /// platform channel failed, which the gate treats as below any minimum.
  static int? get versionCode => _versionCode;

  /// `versionName` (`1.1.20`), display only.
  static String? get versionName => _versionName;

  static bool get isLoaded => _loaded;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _versionCode = int.tryParse(info.buildNumber);
      _versionName = info.version.trim().isEmpty ? null : info.version.trim();
    } catch (e) {
      debugPrint('[force-update] cannot read package info: $e');
    } finally {
      _loaded = true;
    }
  }

  /// Test seam. Production code must go through [load].
  @visibleForTesting
  static void overrideForTest({int? versionCode, String? versionName}) {
    _versionCode = versionCode;
    _versionName = versionName;
    _loaded = true;
  }
}
