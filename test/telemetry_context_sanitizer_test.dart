import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_context_sanitizer.dart';
import 'package:dpd_userapp/core/telemetry/telemetry_event_types.dart';

void main() {
  test('keeps allowlisted keys for the event', () {
    final result = sanitizeTelemetryContext(TelemetryEvents.screenOpen, {
      'screen': 'add_delivery',
      'from_screen': 'home',
      'load_ms': 42,
    });

    expect(result.context, {
      'screen': 'add_delivery',
      'from_screen': 'home',
      'load_ms': 42,
    });
    expect(result.strippedKeys, isEmpty);
  });

  test('strips a key that is not allowlisted for this event', () {
    final result = sanitizeTelemetryContext(TelemetryEvents.screenOpen, {
      'screen': 'home',
      'depth': 5,
    });

    expect(result.context, {'screen': 'home'});
    expect(result.strippedKeys, ['depth']);
  });

  test('strips denied keys even when they look allowlisted', () {
    for (final key in const [
      'access_token',
      'password',
      'passcode',
      'phone_number',
      'civil_id',
      'address',
      'authorization',
      'message',
      'stack',
      'lat',
      'lng',
      'otp',
    ]) {
      final result = sanitizeTelemetryContext(
        TelemetryEvents.clientError,
        {key: 'x'},
      );
      expect(result.context, isEmpty, reason: 'key $key must be stripped');
      expect(result.strippedKeys, [key]);
    }
  });

  test('retryable survives the pin/lat word denylist', () {
    final result = sanitizeTelemetryContext(TelemetryEvents.clientError, {
      'code': 'upload_failed',
      'retryable': true,
      'http_status': 500,
    });
    expect(result.context, {
      'code': 'upload_failed',
      'retryable': true,
      'http_status': 500,
    });
  });

  test('drops nested maps and lists, which is how a stack trace would arrive',
      () {
    final result = sanitizeTelemetryContext(TelemetryEvents.clientError, {
      'code': {'nested': 'value'},
      'http_status': [500],
    });
    expect(result.context, isEmpty);
    expect(result.strippedKeys, containsAll(['code', 'http_status']));
  });

  test('truncates long strings at 120 characters', () {
    final long = 'a' * 200;
    final result = sanitizeTelemetryContext(
      TelemetryEvents.appClientInfo,
      {'device_model': long},
    );
    expect(
      (result.context['device_model'] as String).length,
      telemetryMaxStringLength,
    );
  });

  test('identifier keys reject a sentence or a phone-like value', () {
    final result = sanitizeTelemetryContext(TelemetryEvents.clientError, {
      'code': 'Something went wrong: +965 1234 5678',
      'screen': 'finish_delivery',
    });
    expect(result.context, {'screen': 'finish_delivery'});
    expect(result.strippedKeys, ['code']);
  });

  test('a context over 1024 characters is flagged for dropping', () {
    final context = <String, Object?>{
      'device_model': 'm' * 120,
      'os_version': 'o' * 120,
      'platform': 'p' * 120,
      'app_version_name': 'v' * 120,
      'locale': 'l' * 120,
    };
    expect(telemetryContextExceedsLimit(context), isFalse);

    final oversized = {
      for (var i = 0; i < 40; i++) 'device_model$i': 'x' * 120,
    };
    expect(telemetryContextExceedsLimit(oversized), isTrue);
  });
}
