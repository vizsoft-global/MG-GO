import 'package:dpd_userapp/features/home/home_duty_errors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inactive account cannot start duty', () {
    expect(
      friendlyHomeDutyError('inactive'),
      'Your account is not active',
    );
  });

  test('shift_required is unchanged', () {
    expect(
      friendlyHomeDutyError('shift_required'),
      "Submit today's shift before going on duty.",
    );
  });
}
