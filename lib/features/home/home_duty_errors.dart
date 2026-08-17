import '../../l10n/app_localizations.dart';

/// A duty write the server refused outright.
///
/// This is the server's answer, not a failure to reach it: replaying it can
/// only reproduce the same refusal, so a rejection must never enter the
/// offline queue and must never be hidden behind the cached dashboard.
enum DutyRejection {
  accountNotActive,
  shiftRequired,
  notAuthenticated,
  serverOutdated,
}

/// Classifies a PostgREST error message. Returns null for anything that could
/// succeed on a later attempt (timeouts, 5xx, connection resets).
DutyRejection? dutyRejectionFrom(String? message) {
  final msg = (message ?? '').toLowerCase();
  if (msg.isEmpty) return null;
  if (msg.contains('not_authenticated')) return DutyRejection.notAuthenticated;
  if (msg.contains('could not find the function')) {
    return DutyRejection.serverOutdated;
  }
  if (msg.contains('shift_required')) return DutyRejection.shiftRequired;
  if (msg.contains('inactive') || msg.contains('driver_suspended')) {
    return DutyRejection.accountNotActive;
  }
  return null;
}

/// Whether a queued duty row should be dropped rather than retried.
///
/// Narrower than [dutyRejectionFrom] on purpose: an auth failure can clear once
/// the session refreshes, and a missing function can come back with a server
/// deploy, so dropping a rider's queued clock-out on either would lose work the
/// server would have accepted.
bool isPermanentDutyQueueRejection(String? message) {
  return switch (dutyRejectionFrom(message)) {
    DutyRejection.accountNotActive || DutyRejection.shiftRequired => true,
    DutyRejection.notAuthenticated ||
    DutyRejection.serverOutdated ||
    null => false,
  };
}

/// Maps PostgREST duty/home errors to the copy shown on the Home toggle.
String friendlyHomeDutyError(String message) {
  final msg = message.trim();
  switch (dutyRejectionFrom(msg)) {
    case DutyRejection.notAuthenticated:
      return 'Session expired. Please sign in again.';
    case DutyRejection.serverOutdated:
      return 'Server update required. Contact support.';
    case DutyRejection.shiftRequired:
      return 'Submit today\'s shift before going on duty.';
    case DutyRejection.accountNotActive:
      return 'Your account is inactive or suspended. Please contact your administrator.';
    case null:
      return msg.isEmpty ? 'Could not load home dashboard' : msg;
  }
}

/// Rider-facing copy for a refusal. Every branch is an ARB string: a driver who
/// cannot clock in has to be told why in their own language.
String dutyRejectionMessage(AppLocalizations l10n, DutyRejection rejection) {
  return switch (rejection) {
    DutyRejection.accountNotActive => l10n.accountNotActive,
    DutyRejection.shiftRequired => l10n.shiftRequiredBeforeDuty,
    DutyRejection.notAuthenticated => l10n.sessionExpired,
    DutyRejection.serverOutdated => l10n.serverUpdateRequired,
  };
}
