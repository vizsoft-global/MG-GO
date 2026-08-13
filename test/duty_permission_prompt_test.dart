import 'package:dpd_userapp/core/permissions/duty_permission_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('re-login while on duty prompts when permissions were revoked', () {
    expect(
      shouldPromptDutyPermissions(
        isOnDuty: true,
        permissionsReady: false,
        promptAlreadyOpen: false,
        dismissedThisForeground: false,
      ),
      isTrue,
    );
  });

  test('does not prompt when off duty or permissions are already granted', () {
    expect(
      shouldPromptDutyPermissions(
        isOnDuty: false,
        permissionsReady: false,
        promptAlreadyOpen: false,
        dismissedThisForeground: false,
      ),
      isFalse,
    );
    expect(
      shouldPromptDutyPermissions(
        isOnDuty: true,
        permissionsReady: true,
        promptAlreadyOpen: false,
        dismissedThisForeground: false,
      ),
      isFalse,
    );
  });

  test('does not re-open the sheet in the same foreground after dismiss', () {
    expect(
      shouldPromptDutyPermissions(
        isOnDuty: true,
        permissionsReady: false,
        promptAlreadyOpen: false,
        dismissedThisForeground: true,
      ),
      isFalse,
    );
    expect(
      shouldPromptDutyPermissions(
        isOnDuty: true,
        permissionsReady: false,
        promptAlreadyOpen: true,
        dismissedThisForeground: false,
      ),
      isFalse,
    );
  });
}
