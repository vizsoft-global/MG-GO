import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'telemetry_context_sanitizer.dart';
import 'telemetry_event.dart';
import 'telemetry_event_types.dart';
import 'telemetry_queue_policy.dart';
import 'telemetry_store.dart';

typedef TelemetryRpc = Future<Object?> Function(
  List<Map<String, Object?>> events,
);
typedef TelemetryUidReader = String? Function();

final telemetryServiceProvider = Provider<TelemetryService>(
  (ref) => TelemetryService.instance,
);

/// Owns the bounded telemetry queue and the batched upload.
///
/// Everything here is best-effort: telemetry must never surface to the driver,
/// block an action, or influence the app's own online/offline truth (so it
/// deliberately does not call `recordRpcSuccess/Failure`).
class TelemetryService {
  TelemetryService({
    TelemetryStore? store,
    TelemetryRpc? rpc,
    TelemetryUidReader? uid,
    String? sessionId,
    DateTime Function()? clock,
    String Function()? idFactory,
  })  : _store = store ?? const OfflineDbTelemetryStore(),
        _rpc = rpc,
        _uidReader = uid,
        _clock = clock ?? DateTime.now,
        _idFactory = idFactory ?? (() => const Uuid().v4()),
        _sessionId = sessionId ?? const Uuid().v4();

  static final TelemetryService instance = TelemetryService();

  final TelemetryStore _store;
  final TelemetryRpc? _rpc;
  final TelemetryUidReader? _uidReader;
  final DateTime Function() _clock;
  final String Function() _idFactory;
  final String _sessionId;

  String? _platform;
  String? _appVersionName;
  int? _appVersionCode;
  String? _networkState;

  int? _count;
  int _droppedPendingNotice = 0;
  bool _flushing = false;
  int _batchSize = kTelemetryMaxBatchSize;
  int _attemptCount = 0;
  DateTime? _nextAttemptAt;
  DateTime? _cooldownUntil;

  /// The uid that came back `not_a_driver`. Scoped to that uid and cleared on
  /// the next auth transition, so the suppression can never become permanent
  /// and can never spill onto a different driver.
  String? _notADriverUid;

  String get sessionId => _sessionId;

  @visibleForTesting
  int? get cachedCount => _count;

  @visibleForTesting
  String? get suppressedUid => _notADriverUid;

  @visibleForTesting
  DateTime? get cooldownUntil => _cooldownUntil;

  void configureClient({
    String? platform,
    String? appVersionName,
    int? appVersionCode,
  }) {
    _platform = platform ?? _platform;
    _appVersionName = appVersionName ?? _appVersionName;
    _appVersionCode = appVersionCode ?? _appVersionCode;
  }

  void setNetworkState(String? state) => _networkState = state;

  /// Clears the `not_a_driver` suppression. Called on sign-in, sign-out and any
  /// uid change — never on a token refresh for the same uid, which is not an
  /// auth transition.
  void clearAuthSuppression() => _notADriverUid = null;

  /// Fire-and-forget entry point for call sites.
  void log(
    String eventName, {
    Map<String, Object?>? context,
    String severity = 'info',
    String? correlationId,
  }) {
    unawaited(record(
      eventName,
      context: context,
      severity: severity,
      correlationId: correlationId,
    ));
  }

  Future<void> record(
    String eventName, {
    Map<String, Object?>? context,
    String severity = 'info',
    String? correlationId,
  }) async {
    await _record(
      eventName,
      context: context,
      severity: severity,
      correlationId: correlationId,
      notifyOverflow: true,
    );
  }

  Future<void> _record(
    String eventName, {
    Map<String, Object?>? context,
    String severity = 'info',
    String? correlationId,
    required bool notifyOverflow,
  }) async {
    try {
      if (!isKnownTelemetryEvent(eventName)) return;

      final sanitized = sanitizeTelemetryContext(eventName, context);
      if (telemetryContextExceedsLimit(sanitized.context)) return;

      final event = TelemetryEvent(
        eventId: _idFactory(),
        userId: _currentUid(),
        eventName: eventName,
        category: telemetryCategoryFor(eventName),
        clientTs: _clock(),
        sessionId: _sessionId,
        correlationId: correlationId,
        severity: eventName == TelemetryEvents.clientError ? 'error' : severity,
        networkState: _networkState,
        platform: _platform,
        appVersionName: _appVersionName,
        appVersionCode: _appVersionCode,
        context: sanitized.context,
      );

      await _store.insert(event);
      _count = (await _ensureCount()) + 1;

      // Hard cap first, so the queue is bounded even while a notice is pending.
      final dropped = await _store.trimToCap(kTelemetryMaxQueueRows);
      if (dropped > 0) {
        _count = _count! - dropped;
        // Only a real event's drop is worth reporting. A drop caused by writing
        // the overflow notice itself is not counted, which is what stops the
        // notice from feeding the next notice on a permanently full queue.
        if (notifyOverflow) _droppedPendingNotice += dropped;
      }

      if (notifyOverflow && _count! >= kTelemetryFlushDepthThreshold) {
        unawaited(flush(reason: 'depth'));
      }
    } catch (error) {
      debugPrint('[telemetry] enqueue skipped: $error');
    }
  }

  Future<int> _ensureCount() async {
    return _count ??= await _store.count();
  }

  String? _currentUid() {
    final reader = _uidReader;
    if (reader != null) return reader();
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<Object?> _callRpc(List<Map<String, Object?>> events) {
    final rpc = _rpc;
    if (rpc != null) return rpc(events);
    return Supabase.instance.client
        .rpc('driver_ingest_telemetry', params: {'p_events': events});
  }

  /// True when there is nothing worth a network call, so the 60s timer stays
  /// silent on an idle app.
  Future<bool> get hasQueuedEvents async {
    try {
      return (await _ensureCount()) > 0;
    } catch (error) {
      // No local database (web, or a failed init): telemetry stays silent
      // rather than raising out of a timer callback.
      debugPrint('[telemetry] queue unavailable: $error');
      return false;
    }
  }

  Future<void> flush({required String reason, bool force = false}) async {
    if (_flushing) return;
    final uid = _currentUid();
    // No session yet: keep everything queued for after login.
    if (uid == null) return;
    if (_notADriverUid == uid) return;

    final now = _clock();
    if (!force) {
      if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) return;
      if (_nextAttemptAt != null && now.isBefore(_nextAttemptAt!)) return;
    }

    _flushing = true;
    try {
      await _emitOverflowNotice();
      await _store.deleteForeignUsers(uid);
      await _store.adoptUnassigned(uid);
      await _store.deleteOutsideWindow(
        now.subtract(kTelemetryClientTsWindow),
        now.add(kTelemetryClientTsWindow),
      );
      _count = await _store.count();

      for (var i = 0; i < kTelemetryMaxBatchesPerFlush; i++) {
        final batch = await _store.take(_batchSize);
        if (batch.isEmpty) break;
        final outcome = await _send(batch);
        final keepGoing = await _apply(outcome, batch, uid);
        if (!keepGoing) break;
      }
    } catch (error) {
      debugPrint('[telemetry] flush($reason) failed: $error');
    } finally {
      _flushing = false;
    }
  }

  /// One `queue.created` per flush cycle carrying the accumulated drop count.
  /// Written through the internal path so it can never trigger another notice.
  Future<void> _emitOverflowNotice() async {
    if (_droppedPendingNotice <= 0) return;
    final dropped = _droppedPendingNotice;
    _droppedPendingNotice = 0;
    await _record(
      TelemetryEvents.queueCreated,
      context: {
        'queue': 'telemetry',
        'depth': await _ensureCount(),
        'dropped': dropped,
        'reason': 'overflow',
      },
      severity: 'warn',
      notifyOverflow: false,
    );
  }

  Future<TelemetryFlushOutcome> _send(List<TelemetryEvent> batch) async {
    try {
      final result = await _callRpc(
        batch.map((e) => e.toRpcJson()).toList(growable: false),
      );
      return classifyTelemetryResponse(result);
    } catch (error) {
      // Transport, timeout or server fault: keep the rows and back off.
      return TelemetryFlushOutcome(
        disposition: TelemetryFlushDisposition.retryLater,
        error: error.runtimeType.toString(),
      );
    }
  }

  Future<bool> _apply(
    TelemetryFlushOutcome outcome,
    List<TelemetryEvent> batch,
    String uid,
  ) async {
    final ids = batch.map((e) => e.eventId).toList(growable: false);

    switch (outcome.disposition) {
      case TelemetryFlushDisposition.accepted:
        await _store.deleteIds(ids);
        _count = await _store.count();
        _attemptCount = 0;
        _nextAttemptAt = null;
        return batch.length >= _batchSize;

      case TelemetryFlushDisposition.throttled:
        await _store.deleteIds(ids);
        _count = await _store.count();
        _cooldownUntil = _clock().add(kTelemetryThrottleCooldown);
        return false;

      case TelemetryFlushDisposition.keepUnauthenticated:
        return false;

      case TelemetryFlushDisposition.notADriver:
        await _store.deleteIds(ids);
        _count = await _store.count();
        _notADriverUid = uid;
        return false;

      case TelemetryFlushDisposition.clientBug:
        await _store.deleteIds(ids);
        _count = await _store.count();
        final halved = _batchSize ~/ 2;
        _batchSize =
            halved < kTelemetryMinBatchSize ? kTelemetryMinBatchSize : halved;
        debugPrint('[telemetry] batch dropped: ${outcome.error}');
        return false;

      case TelemetryFlushDisposition.retryLater:
        await _store.bumpAttempts(ids, outcome.error ?? 'retry');
        _attemptCount += 1;
        final backoff = telemetryBackoffFor(_attemptCount);
        _nextAttemptAt = backoff == null ? null : _clock().add(backoff);
        return false;
    }
  }
}
