import 'package:camera/camera.dart';
import 'package:dpd_userapp/features/deliveries/widgets/delivery_proof_widgets.dart';
import 'package:dpd_userapp/features/deliveries/widgets/rear_camera_capture_screen.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _l10nApp(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('pickup and finish proof areas are take-photo only, not gallery',
      (tester) async {
    await tester.pumpWidget(
      _l10nApp(
        const Scaffold(
          body: DeliveryProofUploadArea(cameraOnly: true, onTap: null),
        ),
      ),
    );

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Take photo or choose from gallery'), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
  });

  testWidgets('rear capture has no flip or gallery when there is no rear camera',
      (tester) async {
    await tester.pumpWidget(
      _l10nApp(
        RearCameraCaptureScreen(
          cameras: [
            const CameraDescription(
              name: '1',
              lensDirection: CameraLensDirection.front,
              sensorOrientation: 90,
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('Rear camera is required to take an order photo.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cameraswitch), findsNothing);
    expect(find.byIcon(Icons.flip_camera_android), findsNothing);
    expect(find.byIcon(Icons.flip_camera_ios), findsNothing);
    expect(find.byIcon(Icons.photo_library), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    expect(find.byKey(const Key('rear-camera-shutter')), findsNothing);
  });
}
