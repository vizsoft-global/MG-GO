/// Every number and every "what do I do with this response" decision lives
/// here, in one file with no I/O, so the tests assert against the same
/// constants the service uses instead of a second copy of them.
library;

/// Flush as soon as the queue reaches this depth.
const int kTelemetryFlushDepthThreshold = 25;

/// Never more than this per RPC call. The server rejects a larger batch with
/// `batch_too_large`.
const int kTelemetryMaxBatchSize = 100;

/// Bounded FIFO: past this many rows the oldest are dropped.
const int kTelemetryMaxQueueRows = 2000;

/// A single flush sends at most this many batches, so a huge backlog cannot
/// hold the flush loop open indefinitely.
const int kTelemetryMaxBatchesPerFlush = 5;

/// Floor for the self-reducing batch size used after a `batch_too_large`.
const int kTelemetryMinBatchSize = 10;

/// The server refuses a `client_ts` outside this window, so such rows are
/// dropped before they are sent.
const Duration kTelemetryClientTsWindow = Duration(days: 7);

/// After `throttled` there is no point flushing again immediately: the hourly
/// quota is closed and retrying only burns battery.
const Duration kTelemetryThrottleCooldown = Duration(minutes: 15);

/// Periodic flush interval.
const Duration kTelemetryFlushInterval = Duration(seconds: 60);

/// Retry schedule for network and 5xx failures only.
const List<Duration> kTelemetryBackoff = [
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 60),
  Duration(seconds: 300),
];

/// Backoff for the given attempt count (1-based). `null` means the schedule is
/// exhausted: hold and wait for the next trigger.
Duration? telemetryBackoffFor(int attemptCount) {
  if (attemptCount <= 0) return kTelemetryBackoff.first;
  if (attemptCount > kTelemetryBackoff.length) return null;
  return kTelemetryBackoff[attemptCount - 1];
}

/// How many rows must be dropped to keep the queue at its cap.
int telemetryOverflowCount(int currentRows, {int cap = kTelemetryMaxQueueRows}) {
  final overflow = currentRows - cap;
  return overflow > 0 ? overflow : 0;
}

/// What the caller should do with the batch it just sent.
enum TelemetryFlushDisposition {
  /// Stored (or duplicate, or per-event rejected): delete the whole batch.
  accepted,

  /// Quota closed. Delete the batch and stop until the cooldown expires.
  throttled,

  /// Not signed in yet. Keep the rows for after login, do not back off.
  keepUnauthenticated,

  /// Signed in, but this uid has no driver row. Drop the batch and suppress
  /// flushing for this uid only, until the next auth transition.
  notADriver,

  /// `invalid_payload` / `batch_too_large`: the batch can never be accepted as
  /// sent. Drop it and shrink the batch size; never loop on it.
  clientBug,

  /// Network, timeout or 5xx. Keep the rows and back off.
  retryLater,
}

class TelemetryFlushOutcome {
  const TelemetryFlushOutcome({
    required this.disposition,
    this.accepted = 0,
    this.duplicates = 0,
    this.rejected = 0,
    this.rejectedEventIds = const [],
    this.error,
  });

  final TelemetryFlushDisposition disposition;
  final int accepted;
  final int duplicates;
  final int rejected;
  final List<String> rejectedEventIds;
  final String? error;
}

/// Classifies the RPC result object. The RPC returns a result instead of
/// raising precisely so "drop this" can be told apart from "retry later".
TelemetryFlushOutcome classifyTelemetryResponse(Object? result) {
  if (result is! Map) {
    return const TelemetryFlushOutcome(
      disposition: TelemetryFlushDisposition.clientBug,
      error: 'unexpected_response',
    );
  }
  final map = Map<String, Object?>.from(result);
  final ok = map['ok'];

  if (ok == false) {
    final error = map['error']?.toString() ?? 'unknown_error';
    switch (error) {
      case 'not_authenticated':
        return TelemetryFlushOutcome(
          disposition: TelemetryFlushDisposition.keepUnauthenticated,
          error: error,
        );
      case 'not_a_driver':
        return TelemetryFlushOutcome(
          disposition: TelemetryFlushDisposition.notADriver,
          error: error,
        );
      case 'batch_too_large':
      case 'invalid_payload':
        return TelemetryFlushOutcome(
          disposition: TelemetryFlushDisposition.clientBug,
          error: error,
        );
      default:
        return TelemetryFlushOutcome(
          disposition: TelemetryFlushDisposition.clientBug,
          error: error,
        );
    }
  }

  final rejects = map['rejects'];
  final rejectedIds = <String>[];
  if (rejects is List) {
    for (final entry in rejects) {
      if (entry is Map && entry['event_id'] != null) {
        rejectedIds.add(entry['event_id'].toString());
      }
    }
  }

  return TelemetryFlushOutcome(
    disposition: map['throttled'] == true
        ? TelemetryFlushDisposition.throttled
        : TelemetryFlushDisposition.accepted,
    accepted: _asInt(map['accepted']),
    duplicates: _asInt(map['duplicates']),
    rejected: _asInt(map['rejected']),
    rejectedEventIds: rejectedIds,
  );
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
