/// Decides whether the foreground service may keep talking to the backend
/// with the token it has on disk after that token was refused.
///
/// The service isolate cannot refresh a session: refresh tokens rotate, and a
/// second refresher would invalidate the UI isolate's copy and sign the rider
/// out. Only the UI isolate refreshes — and when Android has torn the activity
/// down while the service keeps running, nobody does. Until now the service
/// retried the same expired bearer every watchdog tick, forever, for every
/// phone in that state: 78k rejected `driver_report_location` calls in two
/// hours on production, none of which could ever have succeeded.
///
/// So a refusal parks the service. It stays parked until either the token on
/// disk *changes* (the UI isolate came back and persisted a fresh one — resume
/// immediately, no waiting out the timer) or the backoff window lapses and it
/// is worth one probe to find out whether anything changed server-side. The
/// window doubles per consecutive refusal and caps at ten minutes, so a phone
/// that will never recover costs the backend six calls an hour instead of
/// hundreds.
class DutyAuthBackoff {
  DutyAuthBackoff({
    this.initial = const Duration(minutes: 1),
    this.max = const Duration(minutes: 10),
  });

  final Duration initial;
  final Duration max;

  String? _rejectedToken;
  DateTime? _rejectedAt;
  int _consecutive = 0;

  /// True while a refusal is being honoured.
  bool get isActive => _rejectedToken != null;

  int get consecutiveRejections => _consecutive;

  Duration get currentWindow {
    if (_consecutive == 0) return Duration.zero;
    var window = initial;
    for (var i = 1; i < _consecutive; i++) {
      window *= 2;
      if (window >= max) return max;
    }
    return window < max ? window : max;
  }

  /// Records that [token] was refused at [now].
  void recordRejection(String token, DateTime now) {
    if (_rejectedToken == token) {
      _consecutive += 1;
    } else {
      _rejectedToken = token;
      _consecutive = 1;
    }
    _rejectedAt = now;
  }

  /// Whether a call with [token] should be skipped at [now].
  ///
  /// A different token than the one refused is always allowed through — that
  /// is the signal the UI isolate refreshed — and clears the backoff.
  bool shouldSkip(String token, DateTime now) {
    final rejected = _rejectedToken;
    final at = _rejectedAt;
    if (rejected == null || at == null) return false;
    if (rejected != token) {
      clear();
      return false;
    }
    return now.difference(at) < currentWindow;
  }

  void clear() {
    _rejectedToken = null;
    _rejectedAt = null;
    _consecutive = 0;
  }
}
