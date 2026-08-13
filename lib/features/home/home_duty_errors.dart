/// Maps PostgREST duty/home errors to the copy shown on the Home toggle.
String friendlyHomeDutyError(String message) {
  final msg = message.trim();
  if (msg.contains('not_authenticated')) {
    return 'Session expired. Please sign in again.';
  }
  if (msg.contains('Could not find the function')) {
    return 'Server update required. Contact support.';
  }
  if (msg.contains('shift_required')) {
    return 'Submit today\'s shift before going on duty.';
  }
  if (msg.contains('inactive') || msg.contains('driver_suspended')) {
    return 'Your account is not active';
  }
  return msg.isEmpty ? 'Could not load home dashboard' : msg;
}
