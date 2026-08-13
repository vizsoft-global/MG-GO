import 'package:dpd_userapp/features/auth/widgets/digit_pin_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(GlobalKey<DigitPinInputState> key) {
  return MaterialApp(
    home: Scaffold(
      body: DigitPinInput(
        key: key,
        length: 6,
        separatorAfter: 3,
      ),
    ),
  );
}

void main() {
  testWidgets('backspace clears digits from the end without tapping each box',
      (tester) async {
    final key = GlobalKey<DigitPinInputState>();
    await tester.pumpWidget(_harness(key));

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(key.currentState!.value, '123456');

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(key.currentState!.value, '12345');

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(key.currentState!.value, '1234');
  });

  testWidgets('IME replace can delete several digits in one edit', (tester) async {
    final key = GlobalKey<DigitPinInputState>();
    await tester.pumpWidget(_harness(key));

    await tester.enterText(find.byType(TextField), '847291');
    await tester.pump();
    expect(key.currentState!.value, '847291');

    await tester.enterText(find.byType(TextField), '84');
    await tester.pump();
    expect(key.currentState!.value, '84');
  });
}
