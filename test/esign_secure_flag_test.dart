import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/esign_secure_flag.dart';
import 'package:dpd_userapp/features/support/request_detail_fields.dart';

void main() {
  test('viewer is fail-open until the category flag is known', () {
    expect(
      esignShouldSecureScreen(
        screenshotRestricted: null,
        screenshotsAllowed: false,
      ),
      isFalse,
    );
    expect(
      esignShouldSecureScreen(
        screenshotRestricted: false,
        screenshotsAllowed: false,
      ),
      isFalse,
    );
    expect(parseScreenshotRestricted(null), isFalse);
    expect(parseScreenshotRestricted(false), isFalse);
  });

  test('capture is fail-closed until the category flag is known', () {
    expect(
      esignShouldSecureScreen(
        screenshotRestricted: null,
        screenshotsAllowed: false,
        failClosed: true,
      ),
      isTrue,
    );
    expect(
      esignShouldSecureScreen(
        screenshotRestricted: false,
        screenshotsAllowed: false,
        failClosed: true,
      ),
      isFalse,
    );
  });

  test('FLAG_SECURE only when restricted and screenshots_allowed is off', () {
    expect(
      esignShouldSecureScreen(
        screenshotRestricted: true,
        screenshotsAllowed: false,
      ),
      isTrue,
    );
    expect(
      esignShouldSecureScreen(
        screenshotRestricted: true,
        screenshotsAllowed: true,
      ),
      isFalse,
    );
    expect(
      esignShouldSecureScreen(
        screenshotRestricted: null,
        screenshotsAllowed: true,
        failClosed: true,
      ),
      isFalse,
    );
  });
}
