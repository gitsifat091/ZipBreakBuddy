import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_break_buddy/core/app_settings.dart';
import 'package:zip_break_buddy/core/reminder.dart';

void main() {
  test('round-trips through JSON', () {
    final s = AppSettings.defaults
        .withReminder(
          const ReminderConfig(
            type: ReminderType.water,
            interval: 30,
            enabled: false,
          ),
        )
        .copyWith(idleMinutes: 8, pomodoro: true, startWithWindows: true);
    final back = AppSettings.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
    );
    expect(back.reminders[ReminderType.water]!.interval, 30);
    expect(back.reminders[ReminderType.water]!.enabled, isFalse);
    expect(back.reminders[ReminderType.posture]!.interval, 20);
    expect(back.idleMinutes, 8);
    expect(back.pomodoro, isTrue);
    expect(back.startWithWindows, isTrue);
  });

  test('sounds and drive-away are on by default', () {
    expect(AppSettings.defaults.soundsEnabled, isTrue);
    expect(AppSettings.defaults.driveAwayEnabled, isTrue);
    // Settings saved before these options existed keep the defaults.
    final old = AppSettings.fromJson({'idleMinutes': 7});
    expect(old.soundsEnabled, isTrue);
    expect(old.driveAwayEnabled, isTrue);
  });

  test('sounds and drive-away round-trip through JSON', () {
    final s = AppSettings.defaults.copyWith(
      soundsEnabled: false,
      driveAwayEnabled: false,
    );
    final back = AppSettings.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
    );
    expect(back.soundsEnabled, isFalse);
    expect(back.driveAwayEnabled, isFalse);
    // The other options are untouched.
    expect(back.pomodoro, isFalse);
  });

  test('non-boolean sounds and drive-away values fall back to on', () {
    final s = AppSettings.fromJson({
      'soundsEnabled': 'no',
      'driveAwayEnabled': 0,
    });
    expect(s.soundsEnabled, isTrue);
    expect(s.driveAwayEnabled, isTrue);
  });

  test('bad or missing fields fall back to defaults', () {
    final s = AppSettings.fromJson({
      'reminders': {
        'posture': {'interval': 'soon', 'enabled': true},
        'eyes': {'interval': 9999},
      },
      'idleMinutes': -3,
    });
    expect(s.reminders[ReminderType.posture]!.interval, 20);
    expect(s.reminders[ReminderType.eyes]!.interval, AppSettings.maxInterval);
    expect(s.reminders[ReminderType.water]!.interval, 45);
    expect(s.idleMinutes, AppSettings.minIdle);
    expect(s.pomodoro, isFalse);
  });

  test('eye reminder is staggered by half its interval', () {
    final s = AppSettings.defaults.withReminder(
      const ReminderConfig(type: ReminderType.eyes, interval: 30),
    );
    final eyes = s.schedule.firstWhere((r) => r.type == ReminderType.eyes);
    expect(eyes.offset, 15);
    expect(AppSettings.defaults.schedule[1].offset, 10);
  });
}
