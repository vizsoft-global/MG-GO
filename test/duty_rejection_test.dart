import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/duty/check_in_context.dart';
import 'package:dpd_userapp/features/home/home_duty_errors.dart';
import 'package:dpd_userapp/l10n/app_localizations_en.dart';

void main() {
  test('classifies check-in refusals as permanent', () {
    expect(
      dutyRejectionFrom('check_in_photo_required'),
      DutyRejection.checkInPhotoRequired,
    );
    expect(
      dutyRejectionFrom('check_in_outside_restaurant_range'),
      DutyRejection.checkInOutsideRestaurantRange,
    );
    expect(
      dutyRejectionFrom('check_in_outside_zone'),
      DutyRejection.checkInOutsideZone,
    );
    expect(
      dutyRejectionFrom('check_in_zone_unassigned'),
      DutyRejection.checkInNoZone,
    );
    expect(isPermanentDutyQueueRejection('check_in_photo_required'), isTrue);
    expect(
      isPermanentDutyQueueRejection('check_in_outside_restaurant_range'),
      isTrue,
    );
    expect(isPermanentDutyQueueRejection('check_in_outside_zone'), isTrue);
    expect(isPermanentDutyQueueRejection('check_in_zone_unassigned'), isTrue);
  });

  test('reads the nearest restaurant detail', () {
    final detail = dutyRefusalDetail(
      _Refusal(
        'check_in_outside_restaurant_range',
        {'nearest_restaurant': 'Salmiya', 'distance_m': 820},
      ),
    );
    expect(detail?.restaurant, 'Salmiya');
    expect(detail?.distanceM, 820);
  });

  test('reads the zone detail a Keeta refusal carries', () {
    final detail = dutyRefusalDetail(
      _Refusal('check_in_outside_zone', {'zone_name': 'Salmiya'}),
    );
    expect(detail?.zone, 'Salmiya');
  });

  test('the zone backstop names the zone, and no-zone sends to the admin', () {
    final en = AppLocalizationsEn();
    final named = dutyRejectionMessage(
      en,
      DutyRejection.checkInOutsideZone,
      detail: const DutyRefusalDetail(zone: 'Salmiya'),
    );
    expect(named, contains('Salmiya'));
    expect(named, isNot(contains('{')));
    expect(
      dutyRejectionMessage(en, DutyRejection.checkInOutsideZone),
      en.checkInOutsideZone,
    );
    expect(
      dutyRejectionMessage(en, DutyRejection.checkInNoZone),
      en.checkInNoZone,
    );
  });

  test('the server backstop names the restaurant when the precheck was bypassed',
      () {
    final en = AppLocalizationsEn();
    final message = dutyRejectionMessage(
      en,
      DutyRejection.checkInOutsideRestaurantRange,
      detail: const DutyRefusalDetail(restaurant: 'Salmiya', distanceM: 820),
    );
    expect(message, contains('Salmiya'));
    expect(message, contains('820'));
    expect(message, isNot(contains('{')));
  });

  test('the precheck block uses the same named-range copy as the backstop', () {
    final en = AppLocalizationsEn();
    final blocked = checkInBlockedMessage(
      en,
      const CheckInContext(
        day: '2026-10-19',
        requiresCheckIn: true,
        checkedInToday: false,
        photoRequired: true,
        proximityMeters: 500,
        inRange: false,
        candidates: 1,
        requiresLocation: false,
        nearest: CheckInRestaurant(
          id: 'r1',
          name: 'Salmiya',
          distanceM: 820,
        ),
      ),
    );
    expect(
      blocked,
      dutyRejectionMessage(
        en,
        DutyRejection.checkInOutsideRestaurantRange,
        detail: const DutyRefusalDetail(restaurant: 'Salmiya', distanceM: 820),
      ),
    );
  });
}

class _Refusal {
  _Refusal(this.message, this.details);

  final String message;
  final Map<String, Object?> details;
}
