import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dpd_userapp/features/support/widgets/signature_pad.dart';

/// Renders the empty pad at the size the capture screen gives it, so the
/// in-pad guides can be compared against RSup/26 `4388:17186` (361x190).
void main() {
  testWidgets('empty pad guides', (tester) async {
    final controller = SignaturePadController();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(361, 190);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SizedBox(
            width: 361,
            height: 190,
            child: SignaturePad(controller: controller),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(SignaturePad),
      matchesGoldenFile('goldens/signature_pad_guides.png'),
    );
  });

  testWidgets('empty pad guides mirror under RTL', (tester) async {
    final controller = SignaturePadController();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(361, 190);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SizedBox(
              width: 361,
              height: 190,
              child: SignaturePad(controller: controller),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(SignaturePad),
      matchesGoldenFile('goldens/signature_pad_guides_rtl.png'),
    );
  });
}
