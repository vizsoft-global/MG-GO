import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/home/zone_monitor_provider.dart';

void main() {
  test('idle outside window is 10 minutes', () {
    expect(zoneIdleTimeoutSeconds, 600);
  });

  test('return grace after delivery is 20 minutes', () {
    expect(zoneReturnGraceSeconds, 1200);
  });

  test('formatCountdown renders mm:ss', () {
    expect(formatCountdown(125), '02:05');
    expect(formatCountdown(0), '00:00');
  });
}
