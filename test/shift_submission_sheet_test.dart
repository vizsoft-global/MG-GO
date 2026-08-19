import 'package:dpd_userapp/features/shift/shift_models.dart';
import 'package:dpd_userapp/features/shift/widgets/shift_submission_sheet.dart';
import 'package:dpd_userapp/features/shift/widgets/shift_time_field.dart';
import 'package:dpd_userapp/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    're-clock-in sheet shows today\'s already-submitted times instead of Select time',
    (tester) async {
      final shift = DailyShift(
        id: 's1',
        shiftDate: DateTime(2026, 8, 19),
        shiftType: ShiftType.single,
        session1Start: '09:00:00',
        session1End: '18:00:00',
        session1EndDayOffset: 0,
        shiftEndAt: DateTime.now().add(const Duration(hours: 4)),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ShiftSubmissionSheet(initial: shift),
            ),
          ),
        ),
      );

      expect(find.text('Select time'), findsNothing);
      expect(find.text('9:00 AM'), findsOneWidget);
      expect(find.text('6:00 PM'), findsOneWidget);
    },
  );

  testWidgets(
    'time picker from a nested bottom sheet opens a dial, not a text field',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: ShiftTimeField(
                        label: 'From',
                        value: null,
                        onChanged: (_) {},
                      ),
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
      await tester.tap(find.text('Select time'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);
      final dialog = tester.widget<TimePickerDialog>(
        find.byType(TimePickerDialog),
      );
      expect(dialog.initialEntryMode, TimePickerEntryMode.dialOnly);
    },
  );
}
