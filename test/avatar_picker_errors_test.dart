import 'package:dpd_userapp/features/profile/avatar_picker_errors.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isCameraPermissionException', () {
    test('maps image_picker camera denial codes', () {
      expect(
        isCameraPermissionException(
          PlatformException(
            code: 'camera_access_denied',
            message: 'The user did not allow camera.',
          ),
        ),
        isTrue,
      );
      expect(
        isCameraPermissionException(
          PlatformException(code: 'camera_access_restricted'),
        ),
        isTrue,
      );
    });

    test('maps a dismissed in-flight permission request as denial, not a crash', () {
      expect(
        isCameraPermissionException(
          PlatformException(
            code: 'PermissionHandler.PermissionManager',
            message: 'A request for permissions is already running',
          ),
        ),
        isTrue,
      );
    });

    test('maps CameraPermissionDenied', () {
      expect(isCameraPermissionException(const CameraPermissionDenied()), isTrue);
    });

    test('does not treat upload failures as camera denial', () {
      expect(isCameraPermissionException(Exception('network')), isFalse);
      expect(
        isCameraPermissionException(PlatformException(code: 'confirm_failed')),
        isFalse,
      );
    });
  });

  testWidgets('camera deny copy is human, never PlatformException', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final message = userMessageIfCameraPermissionDenied(
      PlatformException(
        code: 'camera_access_denied',
        message: 'The user did not allow camera access',
      ),
      l10n,
    );

    expect(message, l10n.profileCameraPermissionDenied);
    expect(message!.toLowerCase(), isNot(contains('platformexception')));
    expect(message.toLowerCase(), isNot(contains('camera_access_denied')));

    final concurrent = userMessageIfCameraPermissionDenied(
      PlatformException(
        code: 'PermissionHandler.PermissionManager',
        message: 'A request for permissions is already running',
      ),
      l10n,
    );
    expect(concurrent, l10n.profileCameraPermissionDenied);
    expect(concurrent!.toLowerCase(), isNot(contains('platformexception')));
    expect(
      concurrent.toLowerCase(),
      isNot(contains('permissionhandler')),
    );

    final typed = userMessageIfCameraPermissionDenied(
      const CameraPermissionDenied(),
      l10n,
    );
    expect(typed, l10n.profileCameraPermissionDenied);
    expect(typed!.toLowerCase(), isNot(contains('camerapermissiondenied')));
  });
}
