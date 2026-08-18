import 'package:dpd_userapp/features/deliveries/add_delivery_flow.dart';
import 'package:dpd_userapp/features/deliveries/delivery_models.dart';
import 'package:dpd_userapp/features/deliveries/finish_leave_duty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldRevertClockInOnLeaveFinish', () {
    test('explicit Clock In from the overlay stays In when Back is pressed', () {
      expect(
        shouldRevertClockInOnLeaveFinish(
          openedFromClockedOut: true,
          completed: false,
        ),
        isFalse,
      );
    });

    test('already-on-duty finish does not clock out on Back', () {
      expect(
        shouldRevertClockInOnLeaveFinish(
          openedFromClockedOut: false,
          completed: false,
        ),
        isFalse,
      );
    });

    test('completing a delivery does not clock out', () {
      expect(
        shouldRevertClockInOnLeaveFinish(
          openedFromClockedOut: true,
          completed: true,
        ),
        isFalse,
      );
    });
  });

  test('finish path does not mark clock-in as provisional', () {
    expect(
      finishDeliveryPath(
        deliveryId: 'abc',
        outcome: FinishOutcome.delivered,
      ),
      '/deliveries/finish/abc?outcome=delivered',
    );
    expect(
      finishDeliveryPath(
        deliveryId: 'abc',
        outcome: FinishOutcome.delivered,
      ).contains('provisionalClockIn'),
      isFalse,
    );
  });
}
