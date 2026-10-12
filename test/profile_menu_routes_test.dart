import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Profile menu rows used to hardcode one shared placeholder, so nine of ten
/// rows opened the same Coming-soon dialog. These assertions are deliberately
/// source-level: the failure mode being guarded is "a row was never wired",
/// and rendering the real screen needs a session, Firebase and the router.
///
/// A whole-screen widget test cannot see an unwired row that still renders, so
/// the check is that every row's handler names a real destination and that no
/// placeholder path survives in the file.
void main() {
  final profileScreen =
      File('lib/features/profile/profile_screen.dart').readAsStringSync();
  final router =
      File('lib/core/router/app_router.dart').readAsStringSync();

  test('no Profile menu row can reach the Coming-soon dialog', () {
    for (final needle in const [
      '_showComingSoon',
      'showComingSoonDialog',
      'coming_soon_dialog',
      'hasRiderManualVideo',
    ]) {
      expect(
        profileScreen.contains(needle),
        isFalse,
        reason: '$needle is back in profile_screen.dart',
      );
    }
  });

  test('every wired Profile row names its destination', () {
    // The row label -> route it must open. Attendance is the one existing
    // in-shell destination, so it switches tabs instead of pushing.
    const expected = {
      'l10n.myProfile': '/profile/details',
      'l10n.wrongAction': '/profile/wrong-actions',
      'l10n.paymentDetails': '/profile/payments',
      'l10n.assets': '/profile/assets',
      'l10n.termsAndConditions': '/profile/terms',
      'l10n.tutorialMaterial': '/profile/tutorial',
      'l10n.userManualVideo': '/profile/manual',
      'l10n.helpAndSupport': '/profile/support',
    };

    for (final entry in expected.entries) {
      final labelIndex = profileScreen.indexOf('label: ${entry.key}');
      expect(labelIndex, isNonNegative, reason: '${entry.key} row is missing');

      // The destination must be named in the same row literal: onTap follows
      // the label, so the window ends at the next ProfileMenuRow.
      final nextRow = profileScreen.indexOf('ProfileMenuRow(', labelIndex + 1);
      final window = profileScreen.substring(
        labelIndex,
        nextRow == -1 ? profileScreen.length : nextRow,
      );
      expect(
        window.contains(entry.value),
        isTrue,
        reason: '${entry.key} does not open ${entry.value}',
      );
    }
  });

  test('each profile destination is registered in the router', () {
    for (final path in const [
      '/profile/details',
      '/profile/wrong-actions',
      '/profile/payments',
      '/profile/assets',
      '/profile/terms',
      '/profile/tutorial',
      '/profile/manual',
      '/profile/support',
    ]) {
      expect(
        router.contains("path: '$path'"),
        isTrue,
        reason: '$path is not declared in app_router.dart',
      );
    }
  });

  test('the profile sub-pages are pushed above the bottom navigation', () {
    // Pushing on the root navigator is what hides the tab bar. A route that
    // forgot it would open the page inside the shell instead.
    for (final path in const [
      '/profile/details',
      '/profile/wrong-actions',
      '/profile/payments',
      '/profile/assets',
      '/profile/terms',
      '/profile/tutorial',
    ]) {
      final routeIndex = router.indexOf("path: '$path'");
      final window = router.substring(routeIndex, routeIndex + 200);
      expect(
        window.contains('parentNavigatorKey: rootNavigatorKey'),
        isTrue,
        reason: '$path is not on the root navigator',
      );
    }
  });
}
