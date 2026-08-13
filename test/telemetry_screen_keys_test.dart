import 'package:dpd_userapp/core/telemetry/telemetry_event_types.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_screen_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('static routes map to their route name', () {
    expect(telemetryScreenKeyForPath('/home'), 'home');
    expect(telemetryScreenKeyForPath('/deliveries'), 'deliveries');
    expect(telemetryScreenKeyForPath('/deliveries/add'), 'add_delivery');
    expect(telemetryScreenKeyForPath('/profile/attendance'), 'attendance');
  });

  test('dynamic segments do not leak into the key', () {
    expect(
      telemetryScreenKeyForPath('/deliveries/finish/9f1c-uuid'),
      'finish_delivery',
    );
    expect(
      telemetryScreenKeyForPath('/earnings/day/2026-08-13'),
      'earnings_day',
    );
    expect(
      telemetryScreenKeyForPath('/profile/support/requests/RCM-9001'),
      'support_request_detail',
    );
  });

  test('the more specific pattern wins', () {
    expect(
      telemetryScreenKeyForPath('/profile/support/sign/abc/capture'),
      'support_esign_capture',
    );
    expect(
      telemetryScreenKeyForPath('/profile/support/sign/abc'),
      'support_esign_detail',
    );
    expect(telemetryScreenKeyForPath('/profile/support/sign'),
        'support_esign_list');
  });

  test('query strings are ignored', () {
    expect(
      telemetryScreenKeyForPath('/deliveries/success?queued=1&stage=pickup'),
      'delivery_success',
    );
  });

  test('an unmapped path falls back rather than inventing a key', () {
    expect(telemetryScreenKeyForPath('/does/not/exist'), kUnknownScreenKey);
  });

  test('every screen key satisfies the server identifier pattern', () {
    final paths = [
      '/home',
      '/deliveries/finish/x',
      '/profile/support/appointments/x/confirmed',
      '/earnings/payout/x',
    ];
    for (final path in paths) {
      final key = telemetryScreenKeyForPath(path);
      expect(telemetryIdentifierPattern.hasMatch(key), isTrue, reason: key);
    }
  });
}
