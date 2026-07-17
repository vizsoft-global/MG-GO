enum SecurityEventType {
  screenshotAttempt('screenshot_attempt'),
  screenRecordAttempt('screen_record_attempt'),
  developerMode('developer_mode'),
  mockLocation('mock_location'),
  mockLocationBlockedAction('mock_location_blocked_action'),
  zoneTimeoutCheckout('zone_timeout_checkout');

  const SecurityEventType(this.value);
  final String value;
}

enum SecuritySeverity {
  info('info'),
  warning('warning'),
  blocked('blocked');

  const SecuritySeverity(this.value);
  final String value;
}
