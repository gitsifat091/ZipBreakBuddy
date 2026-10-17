import 'reminder.dart';

/// Everything the Settings window edits. Intervals are in units.
class AppSettings {
  const AppSettings({
    required this.reminders,
    this.idleMinutes = 5,
    this.startWithWindows = false,
    this.pomodoro = false,
  });

  static final defaults = AppSettings(
    reminders: {for (final r in defaultReminders) r.type: r},
  );

  /// One entry per [ReminderType.regular] type.
  final Map<ReminderType, ReminderConfig> reminders;
  final int idleMinutes;
  final bool startWithWindows;
  final bool pomodoro;

  static const minInterval = 1;
  static const maxInterval = 240;
  static const minIdle = 1;
  static const maxIdle = 60;

  /// The configs to hand the scheduler. The eye reminder is staggered by
  /// half its interval so it lands between posture reminders.
  List<ReminderConfig> get schedule => [
    for (final type in ReminderType.regular)
      if (type == ReminderType.eyes)
        reminders[type]!.copyWith(offset: reminders[type]!.interval ~/ 2)
      else
        reminders[type]!,
  ];

  AppSettings copyWith({
    Map<ReminderType, ReminderConfig>? reminders,
    int? idleMinutes,
    bool? startWithWindows,
    bool? pomodoro,
  }) => AppSettings(
    reminders: reminders ?? this.reminders,
    idleMinutes: idleMinutes ?? this.idleMinutes,
    startWithWindows: startWithWindows ?? this.startWithWindows,
    pomodoro: pomodoro ?? this.pomodoro,
  );

  AppSettings withReminder(ReminderConfig config) =>
      copyWith(reminders: {...reminders, config.type: config});

  Map<String, Object?> toJson() => {
    'reminders': {
      for (final r in reminders.values)
        r.type.name: {'enabled': r.enabled, 'interval': r.interval},
    },
    'idleMinutes': idleMinutes,
    'startWithWindows': startWithWindows,
    'pomodoro': pomodoro,
  };

  /// Tolerant of missing or malformed fields: anything unreadable falls back
  /// to its default, so a bad save never bricks the app.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    final d = defaults;
    final saved = json['reminders'] is Map
        ? json['reminders'] as Map
        : const {};
    return AppSettings(
      reminders: {
        for (final type in ReminderType.regular)
          type: _readReminder(d.reminders[type]!, saved[type.name]),
      },
      idleMinutes: _readInt(
        json['idleMinutes'],
        d.idleMinutes,
        minIdle,
        maxIdle,
      ),
      startWithWindows: json['startWithWindows'] is bool
          ? json['startWithWindows'] as bool
          : d.startWithWindows,
      pomodoro: json['pomodoro'] is bool
          ? json['pomodoro'] as bool
          : d.pomodoro,
    );
  }

  static ReminderConfig _readReminder(ReminderConfig fallback, Object? raw) {
    if (raw is! Map) return fallback;
    return fallback.copyWith(
      enabled: raw['enabled'] is bool ? raw['enabled'] as bool : null,
      interval: _readInt(
        raw['interval'],
        fallback.interval,
        minInterval,
        maxInterval,
      ),
    );
  }

  static int _readInt(Object? raw, int fallback, int min, int max) =>
      raw is int ? raw.clamp(min, max) : fallback;
}
