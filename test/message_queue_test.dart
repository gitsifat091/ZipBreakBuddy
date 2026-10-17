import 'package:flutter_test/flutter_test.dart';
import 'package:zip_break_buddy/core/message_queue.dart';
import 'package:zip_break_buddy/core/reminder.dart';

void main() {
  final posture = ReminderMessage.forType(ReminderType.posture);
  final water = ReminderMessage.forType(ReminderType.water);
  final eyes = ReminderMessage.forType(ReminderType.eyes);

  test('shows one at a time, in arrival order', () {
    final q = MessageQueue();
    expect(q.push(posture), isTrue);
    expect(q.push(water), isFalse);
    expect(q.push(eyes), isFalse);
    expect(q.current, posture);
    expect(q.advance(), water);
    expect(q.advance(), eyes);
    expect(q.advance(), isNull);
    expect(q.push(posture), isTrue);
  });

  test('does not queue a reminder that is already showing or waiting', () {
    final q = MessageQueue()
      ..push(posture)
      ..push(water);
    expect(q.push(ReminderMessage.forType(ReminderType.posture)), isFalse);
    expect(q.push(ReminderMessage.forType(ReminderType.water)), isFalse);
    expect(q.pendingCount, 1);
  });

  test('a Pomodoro phase change drops the stale opposite phase', () {
    final q = MessageQueue()
      ..push(posture)
      ..push(ReminderMessage.forType(ReminderType.pomodoroBreak))
      ..push(water)
      ..push(ReminderMessage.forType(ReminderType.pomodoroFocus));
    expect(q.advance(), water);
    expect(q.advance()!.type, ReminderType.pomodoroFocus);
    expect(q.advance(), isNull);
  });

  test('snooze confirmation replaces current but keeps the line', () {
    final q = MessageQueue()
      ..push(posture)
      ..push(water);
    q.replaceCurrent(ReminderMessage.snoozed);
    expect(q.current, ReminderMessage.snoozed);
    // While the sleepy message shows, the snoozed reminder may fire again.
    expect(q.push(ReminderMessage.forType(ReminderType.posture)), isFalse);
    expect(q.advance(), water);
  });
}
