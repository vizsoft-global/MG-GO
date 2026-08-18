import 'package:dpd_userapp/features/home/home_models.dart';
import 'package:dpd_userapp/features/home/shift_adherence_minutes.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  final start = DateTime.utc(2026, 8, 13, 8, 30); // 11:30 Kuwait
  final end = DateTime.utc(2026, 8, 13, 13, 30); // 16:30 Kuwait

  test('clock-out before shift start is capped at the shift length, not start-to-end plus early arrival', () {
    // 09:35 Kuwait = 06:35 UTC. Raw end-out is 415 min; shift is only 300 min.
    final out = DateTime.utc(2026, 8, 13, 6, 35);
    expect(shiftMinutesEarlyOut(scheduledStart: start, scheduledEnd: end, actualOut: out), 300);
    expect(end.difference(out).inMinutes, 415);
  });

  test('clock-out during the shift is minutes before shift end', () {
    final out = DateTime.utc(2026, 8, 13, 13, 0); // 16:00 Kuwait
    expect(shiftMinutesEarlyOut(scheduledStart: start, scheduledEnd: end, actualOut: out), 30);
  });

  test('clock-out at or after shift end is not early', () {
    expect(
      shiftMinutesEarlyOut(scheduledStart: start, scheduledEnd: end, actualOut: end),
      0,
    );
    expect(
      shiftMinutesEarlyOut(
        scheduledStart: start,
        scheduledEnd: end,
        actualOut: end.add(const Duration(minutes: 10)),
      ),
      0,
    );
  });

  test('open shift has no early-out', () {
    expect(
      shiftMinutesEarlyOut(scheduledStart: start, scheduledEnd: end, actualOut: null),
      0,
    );
  });

  test('fromJson does not trust a raw 415 when clock-out was before shift start', () {
    final adherence = ShiftAdherence.fromJson({
      'scheduled_start_at': '2026-08-13T08:30:00+00:00',
      'scheduled_end_at': '2026-08-13T13:30:00+00:00',
      'actual_in_at': '2026-08-13T06:31:00+00:00',
      'actual_out_at': '2026-08-13T06:35:00+00:00',
      'minutes_late': 0,
      'minutes_early_out': 415,
      'online_seconds': 240,
      'scheduled_seconds': 18000,
    });
    expect(adherence.minutesEarlyOut, 300);
  });

  test('fromJson caps a stale 415 using scheduled_seconds when timestamps are missing', () {
    // Offline cache / older RPC payloads can store the unclamped 415 with no
    // instants. The shift is still only 300 minutes (11:30–16:30).
    final adherence = ShiftAdherence.fromJson({
      'minutes_late': 0,
      'minutes_early_out': 415,
      'online_seconds': 240,
      'scheduled_seconds': 18000,
    });
    expect(adherence.minutesEarlyOut, 300);
  });

  test('fromJson caps mixed-offset 415 using the server scheduled_seconds', () {
    // Start is 11:30 Kuwait as UTC. End/out are naive 16:30 / 09:35, which a
    // UTC device treats as UTC — raw end−out is 415, and isBefore skips the
    // window clamp because 09:35 is after 08:30Z. scheduled_seconds is the
    // shift length the server already computed (300 min).
    final adherence = ShiftAdherence.fromJson({
      'scheduled_start_at': '2026-08-13T08:30:00+00:00',
      'scheduled_end_at': '2026-08-13T16:30:00',
      'actual_in_at': '2026-08-13T09:31:00',
      'actual_out_at': '2026-08-13T09:35:00',
      'minutes_late': 0,
      'minutes_early_out': 415,
      'scheduled_seconds': 18000,
    });
    expect(adherence.minutesEarlyOut, 300);
  });

  test('fromJson does not shrink a during-shift early-out', () {
    final adherence = ShiftAdherence.fromJson({
      'scheduled_start_at': '2026-08-13T08:30:00+00:00',
      'scheduled_end_at': '2026-08-13T13:30:00+00:00',
      'actual_out_at': '2026-08-13T13:00:00+00:00',
      'minutes_early_out': 30,
      'scheduled_seconds': 18000,
    });
    expect(adherence.minutesEarlyOut, 30);
  });

  test('capShiftEarlyOutMinutes leaves an overnight remaining window intact', () {
    expect(capShiftEarlyOutMinutes(720, scheduledSeconds: 43200), 720);
    expect(capShiftEarlyOutMinutes(415, scheduledSeconds: 18000), 300);
    expect(capShiftEarlyOutMinutes(0, scheduledSeconds: 18000), 0);
  });
}
