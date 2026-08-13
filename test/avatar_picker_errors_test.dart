import 'package:dpd_userapp/features/profile/avatar_picker_errors.dart';
import 'package:flutter/services.dart';
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

    test('does not treat upload failures as camera denial', () {
      expect(isCameraPermissionException(Exception('network')), isFalse);
      expect(
        isCameraPermissionException(PlatformException(code: 'confirm_failed')),
        isFalse,
      );
    });
  });
}
