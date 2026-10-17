import 'package:flutter_test/flutter_test.dart';
import 'package:zip_break_buddy/core/reminder.dart';
import 'package:zip_break_buddy/core/reminder_scheduler.dart';

void main() {
  const sec = Duration(seconds: 1);

  test('fires after its interval, then repeats', () {
    final fired = <ReminderType>[];
    final s = ReminderScheduler(
      reminders: const [
        ReminderConfig(type: ReminderType.posture, interval: 3),
      ],
      unit: sec,
      onFire: fired.add,
    );
    for (var i = 0; i < 2; i++) {
      s.tick(sec);
    }
    expect(fired, isEmpty);
    s.tick(sec);
    expect(fired, [ReminderType.posture]);
    for (var i = 0; i < 3; i++) {
      s.tick(sec);
    }
    expect(fired, [ReminderType.posture, ReminderType.posture]);
  });

  test('offset shifts the first firing', () {
    final fired = <(int, ReminderType)>[];
    var t = 0;
    final s = ReminderScheduler(
      reminders: defaultReminders.take(2).toList(), // posture 20, eyes 20 +10
      unit: sec,
      onFire: (type) => fired.add((t, type)),
    );
    for (t = 1; t <= 40; t++) {
      s.tick(sec);
    }
    expect(fired, [
      (10, ReminderType.eyes),
      (20, ReminderType.posture),
      (30, ReminderType.eyes),
      (40, ReminderType.posture),
    ]);
  });

  test('snooze refires after 10 units, then resumes the interval', () {
    final fired = <int>[];
    var t = 0;
    final s = ReminderScheduler(
      reminders: const [ReminderConfig(type: ReminderType.water, interval: 45)],
      unit: sec,
      onFire: (_) => fired.add(t),
    );
    for (t = 1; t <= 45; t++) {
      s.tick(sec);
    }
    s.snooze(ReminderType.water);
    for (t = 46; t <= 100; t++) {
      s.tick(sec);
    }
    expect(fired, [45, 55, 100]);
  });

  group('pomodoro', () {
    late List<(int, ReminderType)> fired;
    late ReminderScheduler s;
    var t = 0;

    setUp(() {
      fired = [];
      s = ReminderScheduler(
        reminders: const [
          ReminderConfig(type: ReminderType.water, interval: 20),
          ReminderConfig(type: ReminderType.breakTime, interval: 10),
        ],
        pomodoro: const PomodoroConfig(),
        unit: sec,
        onFire: (type) => fired.add((t, type)),
      );
    });

    void runUntil(int end) {
      for (t = t + 1; t <= end; t++) {
        s.tick(sec);
      }
      t = end;
    }

    test('cycles 25 focus / 5 rest, replaces break, holds others on rest', () {
      t = 0;
      runUntil(60);
      expect(fired, [
        (20, ReminderType.water),
        (25, ReminderType.pomodoroBreak),
        // Water would be due at 40, but the rest at 25-30 restarted it.
        (30, ReminderType.pomodoroFocus),
        (50, ReminderType.water),
        (55, ReminderType.pomodoroBreak),
        (60, ReminderType.pomodoroFocus),
      ]);
    });

    test('snoozing the break postpones it 10 units', () {
      t = 0;
      runUntil(25);
      expect(s.onPomodoroBreak, isTrue);
      s.snooze(ReminderType.pomodoroBreak);
      expect(s.onPomodoroBreak, isFalse);
      fired.clear();
      runUntil(35);
      expect(fired.last, (35, ReminderType.pomodoroBreak));
    });
  });

  test('disabled reminders never fire', () {
    final fired = <ReminderType>[];
    final s = ReminderScheduler(
      reminders: const [
        ReminderConfig(type: ReminderType.water, interval: 1, enabled: false),
      ],
      unit: sec,
      onFire: fired.add,
    );
    s.tick(sec * 5);
    expect(fired, isEmpty);
    expect(s.remaining(ReminderType.water), isNull);
  });
}
