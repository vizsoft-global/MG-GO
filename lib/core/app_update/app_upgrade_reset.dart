import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../offline/offline_db.dart';

/// Drops read-through caches the first time a newly installed build runs.
///
/// Local caches outlive an app update, so a payload written by an older build
/// is replayed into models that may have changed shape since. When a cached
/// payload no longer parses, the provider reading it lands in an error state
/// and the feature stays broken for that driver — for the proximity context
/// that means Add Delivery is disabled until the cache happens to be rewritten,
/// which never happens because the read throws before any refresh can run.
///
/// Only caches are dropped. Unsynced offline work (`pending_*`) and the auth
/// session are left alone: purging those would lose logged orders and force
/// every driver to sign in again after each release.
class AppUpgradeReset {
  AppUpgradeReset._();

  static const _lastBuildKey = 'last_launched_app_build';

  /// Returns true when a version change was detected and caches were dropped.
  static Future<bool> runIfUpgraded() async {
    if (kIsWeb) return false;

    final String currentBuild;
    try {
      final info = await PackageInfo.fromPlatform();
      currentBuild = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('[upgrade] cannot read package info: $e');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final previousBuild = prefs.getString(_lastBuildKey);

    if (previousBuild == currentBuild) return false;

    // First launch after a fresh install has nothing stale to clear; just
    // record the build so the next real upgrade is detected.
    if (previousBuild == null) {
      await prefs.setString(_lastBuildKey, currentBuild);
      return false;
    }

    try {
      await OfflineDb.instance.clearVolatileCaches();
      debugPrint('[upgrade] caches cleared for $previousBuild -> $currentBuild');
    } catch (e) {
      // Never block startup on the reset — a stale cache is recoverable, a
      // crash loop at launch is not.
      debugPrint('[upgrade] cache purge failed: $e');
      return false;
    }

    await prefs.setString(_lastBuildKey, currentBuild);
    return true;
  }
}
