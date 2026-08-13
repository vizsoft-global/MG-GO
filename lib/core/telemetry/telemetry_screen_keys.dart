/// Maps a go_router location to the `context.screen` value.
///
/// The keys are the router's own route names, which already satisfy the
/// server's identifier pattern. Order matters: the more specific pattern must
/// come first (`/profile/support/sign/:id/capture` before
/// `/profile/support/sign/:id`).
library;

const String kUnknownScreenKey = 'unknown';

const List<(String, String)> _screenPatterns = [
  ('/', 'bootstrap'),
  ('/maintenance', 'maintenance'),
  ('/login', 'login'),
  ('/login-verification', 'login_verification'),
  ('/blocked', 'blocked'),
  ('/deliveries/add', 'add_delivery'),
  ('/deliveries/active', 'active_delivery'),
  ('/deliveries/finish/:id', 'finish_delivery'),
  ('/deliveries/success', 'delivery_success'),
  ('/deliveries/pending', 'pending_deliveries'),
  ('/deliveries', 'deliveries'),
  ('/earnings/extra', 'extra_earnings'),
  ('/earnings/day/:date', 'earnings_day'),
  ('/earnings/payout/:id', 'payout_detail'),
  ('/earnings', 'earnings'),
  ('/notifications', 'notifications'),
  ('/profile/support/action-required', 'support_action_required'),
  ('/profile/support/requests/new', 'support_request_new'),
  ('/profile/support/requests/:id/acknowledged',
      'support_request_acknowledged'),
  ('/profile/support/requests/:id', 'support_request_detail'),
  ('/profile/support/requests', 'support_requests'),
  ('/profile/support/submitted', 'support_request_submitted'),
  ('/profile/support/visits/book', 'support_visit_book'),
  ('/profile/support/visits', 'support_visits'),
  ('/profile/support/sign/:id/capture', 'support_esign_capture'),
  ('/profile/support/sign/:id/confirmed', 'support_esign_confirmed'),
  ('/profile/support/sign/:id', 'support_esign_detail'),
  ('/profile/support/sign', 'support_esign_list'),
  ('/profile/support/appointments/:id/confirmed',
      'support_appointment_confirmed'),
  ('/profile/support/appointments/:id', 'support_appointment_detail'),
  ('/profile/support/appointments', 'support_appointments'),
  ('/profile/support', 'support'),
  ('/profile/attendance', 'attendance'),
  ('/profile', 'profile'),
  ('/home', 'home'),
  ('/vehicle', 'vehicle'),
];

String telemetryScreenKeyForPath(String path) {
  final segments = _segments(path);
  for (final (pattern, key) in _screenPatterns) {
    if (_matches(_segments(pattern), segments)) return key;
  }
  return kUnknownScreenKey;
}

List<String> _segments(String path) {
  final withoutQuery = path.split('?').first;
  return withoutQuery.split('/').where((s) => s.isNotEmpty).toList();
}

bool _matches(List<String> pattern, List<String> actual) {
  if (pattern.length != actual.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    final expected = pattern[i];
    if (expected.startsWith(':')) continue;
    if (expected != actual[i]) return false;
  }
  return true;
}
