import 'package:dpd_userapp/core/permissions/duty_permission_status.dart';
import 'package:dpd_userapp/core/permissions/duty_permissions_service.dart';
import 'package:dpd_userapp/features/duty/widgets/duty_readiness_sheet.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every device check granted, so the sheet's own checklist has nothing to say
/// about a clock-in the server refuses.
class _AllGrantedPermissions extends DutyPermissionsService {
  @override
  Future<DutyReadinessReport> audit(AppLocalizations l10n) async {
    return const DutyReadinessReport(
      items: [
        DutyPermissionItem(
          kind: DutyPermissionKind.fineLocation,
          state: DutyPermissionState.granted,
          requiredForDuty: true,
          title: 'Location',
          description: 'Granted',
        ),
      ],
    );
  }
}

/// Opens the sheet as a modal route, the way the app does — the sheet closes
/// itself with `pop`, so it has to sit above something.
Future<void> _pumpSheet(
  WidgetTester tester, {
  required DutyReadinessCallback onContinue,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => DutyReadinessSheet(
                  onContinue: onContinue,
                  service: _AllGrantedPermissions(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a refused clock-in names the reason and keeps the sheet open',
      (tester) async {
    var calls = 0;
    await _pumpSheet(
      tester,
      onContinue: () async {
        calls++;
        return const DutyStartResult.refused(
          'Your account is inactive or suspended.',
        );
      },
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(calls, 1);
    // The symptom this covers: the sheet used to re-run its audit and show the
    // same green checklist, so the tap read as "nothing happened".
    expect(find.byType(DutyReadinessSheet), findsOneWidget);
    expect(
      find.text('Your account is inactive or suspended.'),
      findsOneWidget,
    );
  });

  testWidgets('a started clock-in closes the sheet with no refusal shown',
      (tester) async {
    await _pumpSheet(
      tester,
      onContinue: () async => const DutyStartResult.started(),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(DutyReadinessSheet), findsNothing);
  });

  testWidgets('a blocked outcome adds no copy over the checklist',
      (tester) async {
    await _pumpSheet(
      tester,
      onContinue: () async => const DutyStartResult.blocked(),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(DutyReadinessSheet), findsOneWidget);
    expect(find.byIcon(Icons.block_outlined), findsNothing);
  });
}
