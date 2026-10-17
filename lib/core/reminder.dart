/// Zip's poses. Each maps to `assets/zip/<name>.svg`.
enum ZipPose { happy, cheer, stern, thirsty, eyerest, sleepy }

extension ZipPoseAsset on ZipPose {
  String get asset => 'assets/zip/zip_$name.svg';
}

enum ReminderType {
  posture('Sit up straight'),
  eyes('Rest your eyes'),
  water('Drink water'),
  breakTime('Break time'),
  pomodoroBreak('Pomodoro break'),
  pomodoroFocus('Pomodoro focus');

  const ReminderType(this.label);
  final String label;

  /// The reminders with their own editable interval.
  static const regular = [posture, eyes, water, breakTime];
}

/// A recurring reminder. [interval] and [offset] are in "units":
/// minutes normally, seconds in debug mode.
class ReminderConfig {
  const ReminderConfig({
    required this.type,
    required this.interval,
    this.offset = 0,
    this.enabled = true,
  });

  final ReminderType type;
  final int interval;

  /// Delay of the first firing relative to a fresh start. 0 means the first
  /// firing happens after one full [interval].
  final int offset;
  final bool enabled;

  ReminderConfig copyWith({int? interval, int? offset, bool? enabled}) =>
      ReminderConfig(
        type: type,
        interval: interval ?? this.interval,
        offset: offset ?? this.offset,
        enabled: enabled ?? this.enabled,
      );
}

/// Pomodoro cycle lengths, in units.
class PomodoroConfig {
  const PomodoroConfig({this.focus = 25, this.rest = 5});

  final int focus;
  final int rest;
}

/// What the pop-up shows.
class ReminderMessage {
  const ReminderMessage(
    this.pose,
    this.text, {
    this.type,
    this.actionable = true,
    this.snoozable = true,
  });

  final ZipPose pose;
  final String text;

  /// The reminder this message belongs to, if any.
  final ReminderType? type;

  /// Whether the pop-up offers Done / Snooze. Informational messages
  /// (like the snooze confirmation) don't.
  final bool actionable;

  /// Whether an actionable pop-up also offers Snooze.
  final bool snoozable;

  static ReminderMessage forType(ReminderType type) => switch (type) {
    ReminderType.posture => ReminderMessage(
      ZipPose.stern,
      "Back straight, shoulders down. Driver's seat posture, please.",
      type: type,
    ),
    ReminderType.eyes => ReminderMessage(
      ZipPose.eyerest,
      'Eyes off the screen. Look far away for 20 seconds.',
      type: type,
    ),
    ReminderType.water => ReminderMessage(
      ZipPose.thirsty,
      'Fuel check! Grab a glass of water before the next lap.',
      type: type,
    ),
    ReminderType.breakTime => ReminderMessage(
      ZipPose.cheer,
      'Nice focus run. Park it and stretch for a minute!',
      type: type,
    ),
    ReminderType.pomodoroBreak => ReminderMessage(
      ZipPose.cheer,
      'Lap complete! Pit stop for 5 minutes. Stand up and stretch.',
      type: type,
    ),
    ReminderType.pomodoroFocus => ReminderMessage(
      ZipPose.happy,
      "Pit stop's over. Engine's warm, let's roll for another 25!",
      type: type,
      snoozable: false,
    ),
  };

  static const snoozed = ReminderMessage(
    ZipPose.sleepy,
    "Engine off for now. I'll honk again in 10 minutes.",
    actionable: false,
  );
}

/// How long a snoozed reminder waits, in units.
const snoozeUnits = 10;

const defaultReminders = [
  ReminderConfig(type: ReminderType.posture, interval: 20),
  ReminderConfig(type: ReminderType.eyes, interval: 20, offset: 10),
  ReminderConfig(type: ReminderType.water, interval: 45),
  ReminderConfig(type: ReminderType.breakTime, interval: 60),
];
