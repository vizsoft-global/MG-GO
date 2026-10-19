import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/home/home_duty_errors.dart';

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
    expect(isPermanentDutyQueueRejection('check_in_photo_required'), isTrue);
    expect(
      isPermanentDutyQueueRejection('check_in_outside_restaurant_range'),
      isTrue,
    );
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
}

class _Refusal {
  _Refusal(this.message, this.details);

  final String message;
  final Map<String, Object?> details;
}
