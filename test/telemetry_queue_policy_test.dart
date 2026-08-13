import 'package:dpd_userapp/core/telemetry/telemetry_queue_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the agreed limits are the ones the code uses', () {
    expect(kTelemetryFlushDepthThreshold, 25);
    expect(kTelemetryMaxBatchSize, 100);
    expect(kTelemetryMaxQueueRows, 2000);
    expect(kTelemetryFlushInterval, const Duration(seconds: 60));
  });

  test('backoff is 5s, 15s, 60s, 300s and then holds', () {
    expect(telemetryBackoffFor(1), const Duration(seconds: 5));
    expect(telemetryBackoffFor(2), const Duration(seconds: 15));
    expect(telemetryBackoffFor(3), const Duration(seconds: 60));
    expect(telemetryBackoffFor(4), const Duration(seconds: 300));
    expect(telemetryBackoffFor(5), isNull);
  });

  test('overflow count is what must be dropped to hold the cap', () {
    expect(telemetryOverflowCount(1999), 0);
    expect(telemetryOverflowCount(2000), 0);
    expect(telemetryOverflowCount(2003), 3);
  });

  group('response classification', () {
    test('ok with counts is accepted', () {
      final outcome = classifyTelemetryResponse({
        'ok': true,
        'accepted': 10,
        'duplicates': 2,
        'rejected': 0,
      });
      expect(outcome.disposition, TelemetryFlushDisposition.accepted);
      expect(outcome.accepted, 10);
      expect(outcome.duplicates, 2);
    });

    test('per-event rejects are reported and the batch still clears', () {
      final outcome = classifyTelemetryResponse({
        'ok': true,
        'accepted': 1,
        'rejected': 1,
        'rejects': [
          {'event_id': 'e1', 'reason': 'unknown_event'},
        ],
      });
      expect(outcome.disposition, TelemetryFlushDisposition.accepted);
      expect(outcome.rejectedEventIds, ['e1']);
    });

    test('throttled is its own disposition, not a retry', () {
      final outcome = classifyTelemetryResponse({
        'ok': true,
        'throttled': true,
        'accepted': 0,
      });
      expect(outcome.disposition, TelemetryFlushDisposition.throttled);
    });

    test('not_authenticated keeps the queue', () {
      final outcome =
          classifyTelemetryResponse({'ok': false, 'error': 'not_authenticated'});
      expect(
        outcome.disposition,
        TelemetryFlushDisposition.keepUnauthenticated,
      );
    });

    test('not_a_driver is a suppression, not a drop-forever', () {
      final outcome =
          classifyTelemetryResponse({'ok': false, 'error': 'not_a_driver'});
      expect(outcome.disposition, TelemetryFlushDisposition.notADriver);
    });

    test('batch_too_large and invalid_payload are client bugs', () {
      for (final error in const ['batch_too_large', 'invalid_payload']) {
        final outcome = classifyTelemetryResponse({'ok': false, 'error': error});
        expect(outcome.disposition, TelemetryFlushDisposition.clientBug);
      }
    });

    test('a non-map response is a client bug, never an infinite retry', () {
      expect(
        classifyTelemetryResponse(null).disposition,
        TelemetryFlushDisposition.clientBug,
      );
      expect(
        classifyTelemetryResponse('boom').disposition,
        TelemetryFlushDisposition.clientBug,
      );
    });
  });
}
