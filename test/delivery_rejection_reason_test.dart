import 'package:dpd_userapp/features/deliveries/delivery_models.dart';
import 'package:dpd_userapp/features/deliveries/widgets/delivery_detail_sheet.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverDelivery.rejectionReason', () {
    test('fromJson maps the admin rejection_reason column', () {
      final delivery = DriverDelivery.fromJson(const {
        'id': '04062111-b1b8-4b27-a678-c723d8aada75',
        'external_order_id': '778890',
        'status': 'rejected',
        'rejection_reason': 'wrong address',
      });
      expect(delivery.rejectionReason, 'wrong address');
    });

    test('fromJson treats missing rejection_reason as null', () {
      final delivery = DriverDelivery.fromJson(const {
        'id': 'id',
        'external_order_id': '10108',
        'status': 'verified',
      });
      expect(delivery.rejectionReason, isNull);
    });
  });

  testWidgets('delivery details overlay shows admin rejection reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DeliveryDetailSheet(
              delivery: DriverDelivery.fromJson(const {
                'id': '04062111-b1b8-4b27-a678-c723d8aada75',
                'external_order_id': '778890',
                'status': 'rejected',
                'rejection_reason': 'wrong address',
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rejection reason'), findsOneWidget);
    expect(find.text('wrong address'), findsOneWidget);
  });

  testWidgets('long rejection reason wraps instead of stacking the label', (
    tester,
  ) async {
    const reason =
        'The submitted proof does not match the delivery location and the '
        'order ID is unreadable so this delivery is rejected after review.';
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: DeliveryDetailSheet(
                delivery: DriverDelivery.fromJson(const {
                  'id': '04062111-b1b8-4b27-a678-c723d8aada75',
                  'external_order_id': '778890',
                  'status': 'rejected',
                  'rejection_reason': reason,
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Rejection reason'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);

    final labelBox = tester.getRect(find.text('Rejection reason'));
    expect(labelBox.width, greaterThan(80));
    expect(labelBox.height, lessThan(48));
  });
}
