enum IdleEvent { none, wentAway, cameBack }

/// Turns raw "time since last input" samples into away/back transitions.
/// Pure logic; the Win32 reading lives in `IdleMonitor`.
class IdleGate {
  IdleGate({required this.threshold});

  Duration threshold;
  bool _away = false;

  bool get isAway => _away;

  IdleEvent update(Duration idleFor) {
    if (!_away && idleFor >= threshold) {
      _away = true;
      return IdleEvent.wentAway;
    }
    if (_away && idleFor < threshold) {
      _away = false;
      return IdleEvent.cameBack;
    }
    return IdleEvent.none;
  }
}
