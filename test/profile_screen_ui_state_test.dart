import 'package:dpd_userapp/features/profile/profile_screen_ui_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed-out session shows leaving, not the profile error page', () {
    expect(
      profileScreenUi(
        hasSession: false,
        isLoading: false,
        hasErrorWithoutValue: false,
        hasProfile: false,
      ),
      ProfileScreenUi.leaving,
    );
  });

  test('session gone during a profile error still leaves, not the error page', () {
    expect(
      profileScreenUi(
        hasSession: false,
        isLoading: false,
        hasErrorWithoutValue: true,
        hasProfile: false,
      ),
      ProfileScreenUi.leaving,
    );
  });

  test('signed-in load failure shows the error page', () {
    expect(
      profileScreenUi(
        hasSession: true,
        isLoading: false,
        hasErrorWithoutValue: true,
        hasProfile: false,
      ),
      ProfileScreenUi.error,
    );
  });

  test('signed-in loading shows the spinner', () {
    expect(
      profileScreenUi(
        hasSession: true,
        isLoading: true,
        hasErrorWithoutValue: false,
        hasProfile: false,
      ),
      ProfileScreenUi.loading,
    );
  });

  test('signed-in profile data is shown', () {
    expect(
      profileScreenUi(
        hasSession: true,
        isLoading: false,
        hasErrorWithoutValue: false,
        hasProfile: true,
      ),
      ProfileScreenUi.data,
    );
  });
}
