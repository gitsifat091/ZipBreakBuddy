import 'reminder.dart';

/// Pure, clock-free reminder timing. The host calls [tick] with elapsed time;
/// tests can drive it directly without real timers.
class ReminderScheduler {
  ReminderScheduler({
    required List<ReminderConfig> reminders,
    PomodoroConfig? pomodoro,
    required this.unit,
    required this.onFire,
  }) {
    configure(reminders, pomodoro: pomodoro);
  }

  /// Length of one interval unit (a minute, or a second in debug mode).
  final Duration unit;
  final void Function(ReminderType type) onFire;

  final Map<ReminderType, ReminderConfig> _configs = {};
  final Map<ReminderType, Duration> _remaining = {};

  PomodoroConfig? _pomodoro;
  bool _onPomodoroBreak = false;
  Duration _pomodoroLeft = Duration.zero;

  /// True during a Pomodoro rest, when the other reminders are on hold.
  bool get onPomodoroBreak => _onPomodoroBreak;

  /// Replaces the reminder set and restarts every countdown fresh.
  /// With [pomodoro] set, the cycle replaces the regular break reminder.
  void configure(List<ReminderConfig> reminders, {PomodoroConfig? pomodoro}) {
    _pomodoro = pomodoro;
    _configs
      ..clear()
      ..addEntries(
        reminders
            .where((r) => r.enabled)
            .where((r) => pomodoro == null || r.type != ReminderType.breakTime)
            .map((r) => MapEntry(r.type, r)),
      );
    reset();
  }

  /// Restarts every countdown from the beginning (including offsets).
  void reset() {
    _resetRegular();
    _onPomodoroBreak = false;
    _pomodoroLeft = unit * (_pomodoro?.focus ?? 0);
  }

  void _resetRegular() {
    _remaining
      ..clear()
      ..addAll(
        _configs.map(
          (type, c) =>
              MapEntry(type, unit * (c.offset > 0 ? c.offset : c.interval)),
        ),
      );
  }

  /// Time left before [type] fires, or null if it is not scheduled.
  Duration? remaining(ReminderType type) => switch (type) {
    ReminderType.pomodoroBreak =>
      _pomodoro != null && !_onPomodoroBreak ? _pomodoroLeft : null,
    ReminderType.pomodoroFocus =>
      _pomodoro != null && _onPomodoroBreak ? _pomodoroLeft : null,
    _ => _remaining[type],
  };

  /// Makes [type] fire again after [snoozeUnits], then resume its interval.
  void snooze(ReminderType type) {
    if (type == ReminderType.pomodoroBreak && _pomodoro != null) {
      // Postpone the rest: keep driving, break again in 10.
      _onPomodoroBreak = false;
      _pomodoroLeft = unit * snoozeUnits;
    } else if (_configs.containsKey(type)) {
      _remaining[type] = unit * snoozeUnits;
    }
  }

  /// Advances all countdowns by [elapsed], firing any that reach zero.
  void tick(Duration elapsed) {
    final pomodoro = _pomodoro;
    if (pomodoro != null) {
      _pomodoroLeft -= elapsed;
      if (_pomodoroLeft <= Duration.zero) {
        _onPomodoroBreak = !_onPomodoroBreak;
        if (_onPomodoroBreak) {
          _pomodoroLeft = unit * pomodoro.rest;
          onFire(ReminderType.pomodoroBreak);
        } else {
          _pomodoroLeft = unit * pomodoro.focus;
          // Back from the rest: the other reminders start fresh too.
          _resetRegular();
          onFire(ReminderType.pomodoroFocus);
        }
        return;
      }
      if (_onPomodoroBreak) return;
    }

    for (final type in _configs.keys) {
      var left = _remaining[type]! - elapsed;
      if (left <= Duration.zero) {
        onFire(type);
        // Fire at most once per tick; restart a full interval from now.
        left = unit * _configs[type]!.interval;
      }
      _remaining[type] = left;
    }
  }
}
