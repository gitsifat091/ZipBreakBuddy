import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/app_settings.dart';
import 'core/idle_gate.dart';
import 'core/message_queue.dart';
import 'core/reminder.dart';
import 'core/reminder_scheduler.dart';
import 'platform/idle_monitor.dart';
import 'platform/settings_store.dart';
import 'ui/toast_slide.dart';

/// Run with `--dart-define=ZIP_DEBUG=true` to count intervals in seconds.
const kZipDebug = bool.fromEnvironment('ZIP_DEBUG');
const unitLabel = kZipDebug ? 'sec' : 'min';

const toastSize = Size(380, 200);
const settingsSize = Size(500, 680);
const _screenMargin = 16.0;
const _ignoredTimeout = Duration(seconds: 30);
const _infoTimeout = Duration(seconds: 4);
const _queueGap = Duration(milliseconds: 700);

/// Wires the tray, the single app window and the scheduler together.
/// The one window is either hidden, the reminder pop-up, or Settings.
class AppController with TrayListener, WindowListener {
  /// The message on screen as a pop-up, or null when none is showing.
  final current = ValueNotifier<ReminderMessage?>(null);

  /// Drives the pop-up's slide: true slides it in, false slides it out.
  final toastIn = ValueNotifier<bool>(false);

  /// Whether the window is currently up as the pop-up.
  bool _toastWindowShown = false;
  int _hideGeneration = 0;

  /// Whether the window is currently the Settings screen.
  final settingsOpen = ValueNotifier<bool>(false);

  AppSettings settings = AppSettings.defaults;

  late final ReminderScheduler scheduler;
  final _store = SettingsStore();
  final _queue = MessageQueue();
  Timer? _ticker;
  Timer? _autoHide;
  final _sinceLastTick = Stopwatch();
  DateTime? _pausedUntil;
  final _idleMonitor = IdleMonitor();
  final _idleGate = IdleGate(threshold: const Duration(minutes: 5));

  Duration get _unit =>
      kZipDebug ? const Duration(seconds: 1) : const Duration(minutes: 1);

  Future<void> init() async {
    launchAtStartup.setup(
      appName: 'Zip Break Buddy',
      appPath: Platform.resolvedExecutable,
    );
    settings = await _store.load();
    // The registry is the source of truth for autostart; keep the toggle honest.
    settings = settings.copyWith(
      startWithWindows: await launchAtStartup.isEnabled(),
    );

    scheduler = ReminderScheduler(
      reminders: const [],
      unit: _unit,
      onFire: _onFire,
    );
    _applySchedule();

    trayManager.addListener(this);
    windowManager.addListener(this);
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('Zip Break Buddy');
    await _rebuildTrayMenu();

    _sinceLastTick.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _applySchedule() {
    scheduler.configure(
      settings.schedule,
      pomodoro: settings.pomodoro ? const PomodoroConfig() : null,
    );
    // Debug mode stretches the idle threshold (5 -> 15s): at plain seconds
    // it would pause whenever you simply watch the screen.
    _idleGate.threshold = kZipDebug
        ? Duration(seconds: settings.idleMinutes * 3)
        : Duration(minutes: settings.idleMinutes);
  }

  void _tick() {
    final elapsed = _sinceLastTick.elapsed;
    _sinceLastTick.reset();
    if (_pausedUntil != null) {
      if (DateTime.now().isBefore(_pausedUntil!)) return;
      _pausedUntil = null;
      scheduler.reset();
      _rebuildTrayMenu();
      return;
    }

    switch (_idleGate.update(_idleMonitor.idleTime())) {
      case IdleEvent.wentAway:
        // Timers stop while away; drop anything waiting so the return
        // isn't greeted by a stack of stale reminders.
        debugPrint('[Zip] user idle, timers paused');
        _clearAll();
        trayManager.setToolTip('Zip Break Buddy (paused while you are away)');
        return;
      case IdleEvent.cameBack:
        debugPrint('[Zip] user back, timers restarted');
        scheduler.reset();
        trayManager.setToolTip('Zip Break Buddy');
        return;
      case IdleEvent.none:
        if (_idleGate.isAway) return;
    }
    scheduler.tick(elapsed);
  }

  void _onFire(ReminderType type) {
    debugPrint('[Zip] fired ${type.name}');
    if (_queue.push(ReminderMessage.forType(type))) _show(_queue.current!);
  }

  // ---- Pop-up ----

  /// Puts [message] on screen and arms the auto-hide timer. While Settings
  /// is open the message just waits at the head of the queue.
  Future<void> _show(ReminderMessage message) async {
    if (settingsOpen.value) return;
    _autoHide?.cancel();
    _autoHide = Timer(
      message.actionable ? _ignoredTimeout : _infoTimeout,
      _advance,
    );
    _hideGeneration++; // Cancels a slide-out still in progress.
    current.value = message;
    if (!_toastWindowShown) {
      _toastWindowShown = true;
      await _showToastWindow();
    }
    // Starts the slide-in (or reverses a slide-out midway).
    toastIn.value = true;
  }

  /// Dismisses the current pop-up and shows the next queued one, if any.
  Future<void> _advance() async {
    _autoHide?.cancel();
    final next = _queue.advance();
    await _hideToast();
    if (next != null) {
      // A short gap so consecutive reminders read as separate pop-ups.
      await Future<void>.delayed(_queueGap);
      if (_queue.current == next) await _show(next);
    }
  }

  void done() => _advance();

  void snooze() {
    final type = current.value?.type;
    if (type != null) scheduler.snooze(type);
    _queue.replaceCurrent(ReminderMessage.snoozed);
    _show(ReminderMessage.snoozed);
  }

  Future<void> _showToastWindow() async {
    await _placeToast();
    await windowManager.setAlwaysOnTop(true);
    // Don't steal keyboard focus from whatever the user is typing in.
    await windowManager.show(inactive: true);
    await _refreshSurface();
  }

  /// Slides the pop-up out, then hides the window. A message shown during
  /// the slide-out wins: it bumps [_hideGeneration] and this bails out.
  Future<void> _hideToast() async {
    if (!_toastWindowShown) return;
    final generation = ++_hideGeneration;
    debugPrint('[Zip] pop-up hiding');
    toastIn.value = false;
    await Future<void>.delayed(toastSlideOut);
    if (generation != _hideGeneration) return;
    _resetToast();
    if (!settingsOpen.value) await windowManager.hide();
  }

  void _resetToast() {
    _hideGeneration++;
    toastIn.value = false;
    current.value = null;
    _toastWindowShown = false;
  }

  /// Drops everything on screen and waiting (e.g. when pausing).
  Future<void> _clearAll() async {
    _autoHide?.cancel();
    _queue.clear();
    await _hideToast();
  }

  Future<void> _placeToast() async {
    final display = await screenRetriever.getPrimaryDisplay();
    final origin = display.visiblePosition ?? Offset.zero;
    final area = display.visibleSize ?? display.size;
    await windowManager.setBounds(
      Rect.fromLTWH(
        origin.dx + area.width - toastSize.width - _screenMargin,
        origin.dy + area.height - toastSize.height - _screenMargin,
        toastSize.width,
        toastSize.height,
      ),
    );
  }

  /// A window resized while hidden keeps a stale render surface on Windows;
  /// a 1px size nudge after showing makes Flutter rebuild it.
  Future<void> _refreshSurface() async {
    final bounds = await windowManager.getBounds();
    await windowManager.setSize(Size(bounds.width + 1, bounds.height));
    await windowManager.setSize(bounds.size);
  }

  // ---- Settings ----

  Future<void> openSettings() async {
    if (settingsOpen.value) {
      await windowManager.focus();
      return;
    }
    // A pop-up on screen goes back to waiting; it returns when Settings closes.
    _autoHide?.cancel();
    _resetToast();
    settingsOpen.value = true;

    await windowManager.hide();
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setSize(settingsSize);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    await _refreshSurface();
  }

  Future<void> closeSettings() async {
    if (!settingsOpen.value) return;
    settingsOpen.value = false;
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
    final waiting = _queue.current;
    if (waiting != null) {
      await Future<void>.delayed(_queueGap);
      if (_queue.current == waiting) await _show(waiting);
    }
  }

  Future<void> saveSettings(AppSettings next) async {
    final autostartChanged = next.startWithWindows != settings.startWithWindows;
    settings = next;
    await _store.save(next);
    if (autostartChanged) {
      try {
        next.startWithWindows
            ? await launchAtStartup.enable()
            : await launchAtStartup.disable();
      } catch (e) {
        debugPrint('[Zip] could not update start with Windows: $e');
      }
    }
    // New intervals start fresh; stale queued reminders go away.
    _queue.clear();
    _applySchedule();
    debugPrint('[Zip] settings saved: ${next.toJson()}');
    await closeSettings();
  }

  // ---- Tray ----

  Future<void> _rebuildTrayMenu() async {
    final paused = _pausedUntil != null;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'pause',
            label: paused ? 'Resume reminders' : 'Pause for 1 hour',
          ),
          MenuItem(key: 'settings', label: 'Settings'),
          if (kZipDebug)
            MenuItem(key: 'test', label: 'Test: fire all reminders'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'pause':
        if (_pausedUntil == null) {
          _pausedUntil = DateTime.now().add(const Duration(hours: 1));
          _clearAll();
        } else {
          _pausedUntil = null;
          scheduler.reset();
        }
        _rebuildTrayMenu();
      case 'settings':
        openSettings();
      case 'test':
        ReminderType.regular.forEach(_onFire);
      case 'quit':
        quit();
    }
  }

  @override
  void onWindowClose() => settingsOpen.value ? closeSettings() : _advance();

  Future<void> quit() async {
    _ticker?.cancel();
    _idleMonitor.dispose();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}
