import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dpd_userapp/features/deliveries/active_delivery_screen.dart';

void main() {
  testWidgets(
    'footer inset clears system nav when padding.bottom is 0 (edge-to-edge)',
    (tester) async {
      const systemNav = 48.0;
      late double inset;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.only(bottom: systemNav),
          ),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                inset = activeDeliveryFooterBottomInset(context);
                return Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: inset),
                      child: const SizedBox(
                        key: Key('cancel_footer'),
                        height: 52,
                        width: double.infinity,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(inset, 16 + systemNav);
      expect(MediaQuery.paddingOf(tester.element(find.byType(Scaffold))).bottom, 0);

      final footer = tester.getRect(find.byKey(const Key('cancel_footer')));
      expect(footer.bottom, lessThanOrEqualTo(844 - systemNav));
      expect(footer.height, 52);
    },
  );

  testWidgets('iOS home-indicator style viewPadding is respected', (tester) async {
    const homeIndicator = 34.0;
    late double inset;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(bottom: homeIndicator),
          viewPadding: EdgeInsets.only(bottom: homeIndicator),
        ),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              inset = activeDeliveryFooterBottomInset(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(inset, 16 + homeIndicator);
  });
}
