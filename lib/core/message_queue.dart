import 'reminder.dart';

/// Ensures only one pop-up is on screen at a time; later messages wait.
class MessageQueue {
  static const _supersedes = {
    ReminderType.pomodoroFocus: ReminderType.pomodoroBreak,
    ReminderType.pomodoroBreak: ReminderType.pomodoroFocus,
  };

  ReminderMessage? _current;
  final List<ReminderMessage> _pending = [];

  ReminderMessage? get current => _current;
  int get pendingCount => _pending.length;

  /// Adds [message]. Returns true if it became [current] and should be shown
  /// now. A reminder already showing or waiting is not queued twice.
  bool push(ReminderMessage message) {
    if (message.type != null && _contains(message.type!)) return false;
    // A Pomodoro phase change makes the opposite, still-waiting one stale.
    final stale = _supersedes[message.type];
    if (stale != null) _pending.removeWhere((m) => m.type == stale);
    if (_current == null) {
      _current = message;
      return true;
    }
    _pending.add(message);
    return false;
  }

  /// Dismisses [current] and returns the next message to show, if any.
  ReminderMessage? advance() {
    _current = _pending.isEmpty ? null : _pending.removeAt(0);
    return _current;
  }

  /// Swaps what is on screen without touching the waiting messages
  /// (used for the snooze confirmation).
  void replaceCurrent(ReminderMessage message) => _current = message;

  void clear() {
    _current = null;
    _pending.clear();
  }

  bool _contains(ReminderType type) =>
      _current?.type == type && _current!.actionable ||
      _pending.any((m) => m.type == type);
}
