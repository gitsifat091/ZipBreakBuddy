import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_break_buddy/core/app_settings.dart';
import 'package:zip_break_buddy/core/reminder.dart';
import 'package:zip_break_buddy/ui/settings_view.dart';
import 'package:zip_break_buddy/ui/theme.dart';

void main() {
  testWidgets('toggles and steppers feed into Save', (tester) async {
    tester.view.physicalSize = const Size(500, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    AppSettings? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildZipTheme(),
        home: Scaffold(
          body: SettingsView(
            initial: AppSettings.defaults,
            unitLabel: 'min',
            onSave: (s) => saved = s,
            onCancel: () {},
          ),
        ),
      ),
    );

    // Switches in order: 4 reminders, Pomodoro, Start with Windows.
    await tester.tap(find.byType(Switch).at(4));
    await tester.pump();
    // Water row "+": the third reminder's add button.
    await tester.tap(find.byIcon(Icons.add_rounded).at(2));
    await tester.pump();
    // Break time is replaced while Pomodoro is on.
    expect(find.text('Replaced by Pomodoro'), findsOneWidget);

    await tester.tap(find.text('Save'));
    expect(saved!.pomodoro, isTrue);
    expect(saved!.reminders[ReminderType.water]!.interval, 50);
    expect(saved!.startWithWindows, isFalse);
  });
}
