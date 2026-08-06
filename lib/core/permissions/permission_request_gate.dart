import 'dart:async';

/// Android allows only one native permission dialog at a time.
/// Concurrent [Permission.request] calls throw
/// `PlatformException(PermissionHandler.PermissionManager, A request for
/// permissions is already running…)`.
class PermissionRequestGate {
  PermissionRequestGate._();

  static Future<void>? _queue;

  /// Runs [action] after any prior permission request fully finishes.
  static Future<T> run<T>(Future<T> Function() action) async {
    while (_queue != null) {
      try {
        await _queue;
      } catch (_) {
        // previous failure must not block the queue forever
      }
    }
    final gate = Completer<void>();
    _queue = gate.future;
    try {
      return await action();
    } finally {
      if (!gate.isCompleted) gate.complete();
      if (identical(_queue, gate.future)) {
        _queue = null;
      }
    }
  }
}
