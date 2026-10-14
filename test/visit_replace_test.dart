import 'package:dpd_userapp/features/support/visit_replace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('book failure leaves the original booking', () async {
    var cancelled = false;
    try {
      await replaceVisitBooking(
        originalId: 'old',
        book: () async => throw Exception('slot_full'),
        cancel: (_) async {
          cancelled = true;
        },
      );
      fail('book should throw');
    } catch (_) {}
    expect(cancelled, isFalse);
  });

  test('cancel failure after book keeps the original and the new row', () async {
    final outcome = await replaceVisitBooking(
      originalId: 'old',
      book: () async => (id: 'new', bookingCode: 'VIS-2'),
      cancel: (_) async => throw Exception('not_cancellable'),
    );
    expect(outcome.originalKept, isTrue);
    expect(outcome.replacementId, 'new');
    expect(outcome.bookingCode, 'VIS-2');
    expect(outcome.cancelFailed, isTrue);
  });

  test('success cancels the original after the new booking', () async {
    final order = <String>[];
    final outcome = await replaceVisitBooking(
      originalId: 'old',
      book: () async {
        order.add('book');
        return (id: 'new', bookingCode: 'VIS-2');
      },
      cancel: (id) async {
        order.add('cancel:$id');
      },
    );
    expect(order, ['book', 'cancel:old']);
    expect(outcome.originalKept, isFalse);
    expect(outcome.cancelFailed, isFalse);
  });
}
