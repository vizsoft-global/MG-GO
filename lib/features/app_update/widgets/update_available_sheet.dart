import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../app_installer.dart';
import '../app_release_models.dart';
import '../app_release_service.dart';
import '../app_update_provider.dart';
import 'update_progress_dialog.dart';

/// Global re-entrancy guard for the in-app update flow.
///
/// `MainShell` calls `_checkForAppUpdate` from `initState` *and* from every
/// `didChangeAppLifecycleState(resumed)`. When the user leaves the app for
/// system settings (to grant install permission) or for Android's "Install
/// this app?" prompt and then returns, the resume event would otherwise
/// kick off a second concurrent flow that stacks dialogs on top of the
/// first one — exactly the "previous popup still stays after I tap
/// Download" symptom users reported. This module-level flag guarantees
/// only one flow can be live at a time.
bool _updateFlowActive = false;

Future<void> showUpdateAvailableSheet(
  BuildContext context,
  WidgetRef ref, {
  required UpdateDecision decision,
}) async {
  if (!decision.hasUpdate || decision.release == null) return;
  if (_updateFlowActive) return;
  _updateFlowActive = true;
  try {
    if (decision.isForced) {
      await runForcedUpdateFlow(context, ref, decision: decision);
      return;
    }
    await _runOptionalUpdateSheet(context, ref, decision.release!);
  } finally {
    _updateFlowActive = false;
  }
}

Future<void> _runOptionalUpdateSheet(
  BuildContext context,
  WidgetRef ref,
  AppRelease release,
) async {

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.updateAvailableTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.updateAvailableBody(release.versionName),
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              if (release.releaseNotes?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  release.releaseNotes!.trim(),
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  if (!context.mounted) return;
                  await _handleDownloadAndInstall(context, ref, release);
                },
                child: Text(l10n.updateDownload),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  ref.read(appUpdateProvider.notifier).markOptionalDismissed();
                  Navigator.of(sheetContext).pop();
                },
                child: Text(l10n.updateLater),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Drives a mandatory update without ever offering the user a "Later" button.
///
/// 1. Ensures `REQUEST_INSTALL_PACKAGES` is granted; if not, shows a blocking
///    dialog that loops until the user grants it or quits the app.
/// 2. Downloads the APK behind a non-dismissible progress dialog.
/// 3. Fires the OS install intent automatically. (Android will still display
///    its own "Do you want to install this app?" system prompt — that is a
///    platform restriction and cannot be silenced for non-system apps.)
/// 4. If download or install launch fails, shows a non-dismissible retry
///    dialog so the user can never end up in the old build silently.
Future<void> runForcedUpdateFlow(
  BuildContext context,
  WidgetRef ref, {
  required UpdateDecision decision,
}) async {
  if (!Platform.isAndroid) return;
  if (!decision.isForced || decision.release == null) return;

  final release = decision.release!;

  while (true) {
    if (!context.mounted) return;
    final attempt = await _attemptForcedDownloadAndInstall(context, ref, release);
    if (attempt.installLaunched || attempt.installIntentLaunched) return;

    if (!context.mounted) return;
    final retry = await _showForcedRetryDialog(
      context,
      release,
      reason: attempt.failureReason,
    );
    if (retry != true) {
      // Dialog auto-loops; this path only fires if the OS killed the context.
      return;
    }
  }
}

class _ForcedAttemptResult {
  const _ForcedAttemptResult({
    required this.installLaunched,
    this.installIntentLaunched = false,
    this.failureReason,
  });

  final bool installLaunched;
  final bool installIntentLaunched;
  final String? failureReason;
}

/// Runs one full forced-update attempt: permission → download → install intent.
/// Captures the precise failure reason so the retry dialog can show it and so
/// Sentry has actionable context next time install silently fails.
Future<_ForcedAttemptResult> _attemptForcedDownloadAndInstall(
  BuildContext context,
  WidgetRef ref,
  AppRelease release,
) async {
  final l10n = context.l10n;

  final granted = await _ensureInstallPermission(context, forced: true);
  if (!granted || !context.mounted) {
    return _ForcedAttemptResult(
      installLaunched: false,
      failureReason: l10n.updateAllowInstallPermission,
    );
  }

  final service = ref.read(appReleaseServiceProvider);
  File? apkFile;
  try {
    apkFile = await showUpdateProgressDialog(
      context,
      onDownload: (onProgress) => service.downloadApk(
        release: release,
        onProgress: onProgress,
      ),
    );
  } on AppReleaseException catch (e, stack) {
    await Sentry.captureException(
      e,
      stackTrace: stack,
      withScope: (scope) => scope.setContexts('app_update', {
        'phase': 'forced_download',
        'version_code': release.versionCode,
        'version_name': release.versionName,
        'code': e.code ?? 'unknown',
      }),
    );
    final reason = e.code == 'checksum_failed'
        ? l10n.updateChecksumFailed
        : (e.message.isNotEmpty ? e.message : l10n.somethingWentWrong);
    return _ForcedAttemptResult(
      installLaunched: false,
      failureReason: reason,
    );
  } catch (e, stack) {
    await Sentry.captureException(
      e,
      stackTrace: stack,
      withScope: (scope) => scope.setContexts('app_update', {
        'phase': 'forced_download_unknown',
        'version_code': release.versionCode,
      }),
    );
    return _ForcedAttemptResult(
      installLaunched: false,
      failureReason: l10n.somethingWentWrong,
    );
  }

  if (apkFile == null || !context.mounted) {
    return _ForcedAttemptResult(
      installLaunched: false,
      failureReason: l10n.somethingWentWrong,
    );
  }

  final installed = await _launchInstallIntent(apkFile, release);
  if (installed.launched) {
    return const _ForcedAttemptResult(
      installLaunched: false,
      installIntentLaunched: true,
    );
  }
  return _ForcedAttemptResult(
    installLaunched: false,
    failureReason: installed.userMessage(l10n),
  );
}

Future<bool?> _showForcedRetryDialog(
  BuildContext context,
  AppRelease release, {
  String? reason,
}) {
  final l10n = context.l10n;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.updateRequiredTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.updateAvailableBody(release.versionName)),
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  reason,
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                      ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.updateDownload),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _handleDownloadAndInstall(
  BuildContext context,
  WidgetRef ref,
  AppRelease release,
) async {
  if (!Platform.isAndroid) return;

  final l10n = context.l10n;
  final granted = await _ensureInstallPermission(context, forced: false);
  if (!granted || !context.mounted) return;

  final service = ref.read(appReleaseServiceProvider);
  File? apkFile;

  try {
    apkFile = await showUpdateProgressDialog(
      context,
      onDownload: (onProgress) => service.downloadApk(
        release: release,
        onProgress: onProgress,
      ),
    );
  } on AppReleaseException catch (e, stack) {
    await Sentry.captureException(
      e,
      stackTrace: stack,
      withScope: (scope) => scope.setContexts('app_update', {
        'phase': 'optional_download',
        'version_code': release.versionCode,
        'version_name': release.versionName,
        'code': e.code ?? 'unknown',
      }),
    );
    if (!context.mounted) return;
    final message = e.code == 'checksum_failed'
        ? l10n.updateChecksumFailed
        : (e.message.isNotEmpty ? e.message : l10n.somethingWentWrong);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return;
  } catch (e, stack) {
    await Sentry.captureException(
      e,
      stackTrace: stack,
      withScope: (scope) => scope.setContexts('app_update', {
        'phase': 'optional_download_unknown',
        'version_code': release.versionCode,
      }),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.somethingWentWrong)),
    );
    return;
  }

  if (apkFile == null || !context.mounted) return;

  final installed = await _launchInstallIntent(apkFile, release);
  if (!context.mounted) return;
  if (!installed.launched) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(installed.userMessage(l10n))),
    );
  }
}

class _InstallLaunchResult {
  const _InstallLaunchResult({
    required this.launched,
    this.errorCode,
    this.errorMessage,
  });

  final bool launched;
  final String? errorCode;
  final String? errorMessage;

  String userMessage(dynamic l10n) {
    switch (errorCode) {
      case 'file_not_found':
        return l10n.updateApkMissing as String;
      case 'install_failed':
        // ActivityNotFoundException → the system installer is unreachable
        // (manifest queries missing on a downstream OEM build, etc.).
        return l10n.updateNoInstallerAvailable as String;
      case null:
        return l10n.somethingWentWrong as String;
      default:
        final msg = (errorMessage ?? '').trim();
        return msg.isNotEmpty ? msg : l10n.somethingWentWrong as String;
    }
  }
}

/// Fires the Android system "Install this app?" intent via the native
/// MethodChannel in `MainActivity.kt`.
///
/// We deliberately avoid `open_filex` here: starting with 4.x it refuses to
/// open APK MIME types without `MANAGE_EXTERNAL_STORAGE`, even when the file
/// lives in our own app-specific external cache, so every forced-update
/// attempt silently returned `permissionDenied` and looped forever.
/// `FileProvider.getUriForFile` + `Intent.ACTION_VIEW` only needs
/// `REQUEST_INSTALL_PACKAGES` (already granted) and the manifest `<queries>`
/// entry for the APK MIME type (added in build 12+).
Future<_InstallLaunchResult> _launchInstallIntent(
  File apkFile,
  AppRelease release,
) async {
  final exists = await apkFile.exists();
  final size = exists ? await apkFile.length() : 0;
  final permissionStatus = await Permission.requestInstallPackages.status;

  try {
    await AppInstaller.installApk(apkFile.path);
    return const _InstallLaunchResult(launched: true);
  } on AppInstallerException catch (e, stack) {
    await Sentry.captureMessage(
      'install_intent_failed: ${e.code} ${e.message}',
      level: SentryLevel.error,
      withScope: (scope) => scope.setContexts('app_update', {
        'phase': 'install_intent_failed',
        'installer_code': e.code,
        'installer_message': e.message,
        'apk_path': apkFile.path,
        'apk_exists': exists,
        'apk_size_bytes': size,
        'permission': permissionStatus.toString(),
        'version_code': release.versionCode,
        'version_name': release.versionName,
      }),
      hint: Hint.withMap({'stack_trace': stack.toString()}),
    );
    return _InstallLaunchResult(
      launched: false,
      errorCode: e.code,
      errorMessage: e.message,
    );
  } catch (e, stack) {
    await Sentry.captureException(
      e,
      stackTrace: stack,
      withScope: (scope) => scope.setContexts('app_update', {
        'phase': 'install_intent_throw',
        'apk_path': apkFile.path,
        'apk_exists': exists,
        'apk_size_bytes': size,
        'permission': permissionStatus.toString(),
        'version_code': release.versionCode,
        'version_name': release.versionName,
      }),
    );
    return _InstallLaunchResult(
      launched: false,
      errorCode: 'install_failed',
      errorMessage: e.toString(),
    );
  }
}

Future<bool> _ensureInstallPermission(
  BuildContext context, {
  required bool forced,
}) async {
  final l10n = context.l10n;

  var status = await Permission.requestInstallPackages.status;
  if (status.isGranted) return true;

  status = await Permission.requestInstallPackages.request();
  if (status.isGranted) return true;

  if (!context.mounted) return false;

  final openSettings = await showDialog<bool>(
    context: context,
    barrierDismissible: !forced,
    builder: (dialogContext) {
      final dialog = AlertDialog(
        title: Text(l10n.updateAllowInstallPermission),
        actions: [
          if (!forced)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.openInstallSettings),
          ),
        ],
      );
      return forced ? PopScope(canPop: false, child: dialog) : dialog;
    },
  );

  if (openSettings == true) {
    await openAppSettings();
    // User returns here after toggling "Install unknown apps". Re-check instead
    // of forcing another retry loop iteration.
    status = await Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
  }
  return false;
}
