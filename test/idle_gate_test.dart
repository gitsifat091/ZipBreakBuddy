import 'package:flutter_test/flutter_test.dart';
import 'package:zip_break_buddy/core/idle_gate.dart';

void main() {
  test('reports away once, then back once', () {
    final g = IdleGate(threshold: const Duration(minutes: 5));
    expect(g.update(const Duration(minutes: 1)), IdleEvent.none);
    expect(g.update(const Duration(minutes: 5)), IdleEvent.wentAway);
    expect(g.isAway, isTrue);
    expect(g.update(const Duration(minutes: 9)), IdleEvent.none);
    expect(g.update(const Duration(seconds: 1)), IdleEvent.cameBack);
    expect(g.isAway, isFalse);
    expect(g.update(const Duration(seconds: 2)), IdleEvent.none);
  });
}
