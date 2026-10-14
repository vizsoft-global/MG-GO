/// Driver visit APIs are book + cancel only. Book first so a failed
/// replacement cannot destroy the original booking.
class VisitReplaceOutcome {
  const VisitReplaceOutcome({
    required this.originalKept,
    required this.replacementId,
    required this.bookingCode,
    required this.cancelFailed,
  });

  final bool originalKept;
  final String? replacementId;
  final String? bookingCode;
  final bool cancelFailed;
}

Future<VisitReplaceOutcome> replaceVisitBooking({
  required Future<({String id, String bookingCode})> Function() book,
  required Future<void> Function(String id) cancel,
  required String originalId,
}) async {
  final booked = await book();
  try {
    await cancel(originalId);
    return VisitReplaceOutcome(
      originalKept: false,
      replacementId: booked.id,
      bookingCode: booked.bookingCode,
      cancelFailed: false,
    );
  } catch (_) {
    return VisitReplaceOutcome(
      originalKept: true,
      replacementId: booked.id,
      bookingCode: booked.bookingCode,
      cancelFailed: true,
    );
  }
}
