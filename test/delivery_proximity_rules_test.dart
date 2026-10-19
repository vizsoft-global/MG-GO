import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/deliveries/delivery_proximity_service.dart';

void main() {
  test('parses the delivery rules snapshot', () {
    final context = DeliveryProximityContext.fromJson({
      'proximity_meters': 500,
      'zone_id': 'z1',
      'zone_type': 'polygon',
      'restaurants': <dynamic>[],
      'rules': {
        'early_drop_meters': 75,
        'required_zone': {'id': 'z1', 'name': 'Salmiya'},
        'dpd_target': 22,
        'rule_name': 'Salmiya weekday',
      },
    });

    expect(context.earlyDropMeters, 75);
    expect(context.requiredZoneName, 'Salmiya');
    expect(context.dpdTarget, 22);
    expect(context.ruleName, 'Salmiya weekday');
  });

  test('falls back to the 50 m default without a rules block', () {
    final context = DeliveryProximityContext.fromJson({
      'proximity_meters': 500,
      'restaurants': <dynamic>[],
    });

    expect(context.earlyDropMeters, 50);
    expect(context.requiredZoneName, isNull);
    expect(context.dpdTarget, isNull);
  });
}
