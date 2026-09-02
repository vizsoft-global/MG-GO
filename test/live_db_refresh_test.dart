import 'package:dpd_userapp/core/branding/app_branding_service.dart';
import 'package:dpd_userapp/core/settings/live_db_refresh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('safety poll is not a per-few-seconds fleet hammer', () {
    expect(LiveDbRefreshCoordinator.pollInterval, const Duration(minutes: 15));
  });

  group('shouldRetryAppSettingsSelect', () {
    test('retries only a missing column', () {
      expect(
        shouldRetryAppSettingsSelect(
          PostgrestException(message: 'column missing', code: '42703'),
        ),
        isTrue,
      );
      expect(
        shouldRetryAppSettingsSelect(
          const PostgrestException(
            message: 'column driver_app_title does not exist',
            code: 'PGRST204',
          ),
        ),
        isTrue,
      );
    });

    test('does not walk fallbacks on an outage', () {
      expect(
        shouldRetryAppSettingsSelect(
          const PostgrestException(message: 'Service Unavailable', code: '503'),
        ),
        isFalse,
      );
      expect(shouldRetryAppSettingsSelect(Exception('timeout')), isFalse);
    });
  });
}
