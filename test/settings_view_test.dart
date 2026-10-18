import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_break_buddy/core/app_settings.dart';
import 'package:zip_break_buddy/core/reminder.dart';
import 'package:zip_break_buddy/ui/settings_view.dart';
import 'package:zip_break_buddy/ui/theme.dart';

void main() {
  testWidgets('toggles and steppers feed into Save', (tester) async {
    tester.view.physicalSize = const Size(500, 700);
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

  testWidgets('Sounds and Drive-away toggles feed into Save', (tester) async {
    tester.view.physicalSize = const Size(500, 700);
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

    Finder switchFor(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

    // Both start on.
    await tester.scrollUntilVisible(find.text('Sounds'), 100);
    expect(tester.widget<Switch>(switchFor('Sounds')).value, isTrue);
    expect(
      tester.widget<Switch>(switchFor('Drive-away animation')).value,
      isTrue,
    );

    await tester.tap(switchFor('Sounds'));
    await tester.pump();
    await tester.tap(switchFor('Drive-away animation'));
    await tester.pump();
    await tester.tap(find.text('Save'));

    expect(saved!.soundsEnabled, isFalse);
    expect(saved!.driveAwayEnabled, isFalse);
    expect(saved!.pomodoro, isFalse);
  });
}
