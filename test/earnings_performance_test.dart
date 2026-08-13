import 'package:dpd_userapp/features/earnings/earnings_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerformanceSummary.fromJson', () {
    test('reads driver_get_earnings_summary total_deliveries, not verified', () {
      const rpc = {
        'ok': true,
        'total_deliveries': 10,
        'verified_deliveries': 5,
        'pending_deliveries': 3,
        'rejected_deliveries': 2,
      };
      final summary = PerformanceSummary.fromJson({
        'total_deliveries': rpc['total_deliveries'],
        'working_days': 4,
        'attendance_pct': 100,
      });
      expect(summary.totalDeliveries, 10);
      expect(summary.totalDeliveries, isNot(rpc['verified_deliveries']));
    });
  });
}
