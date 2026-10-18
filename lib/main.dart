import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'ui/drive_away_view.dart';
import 'ui/reminder_toast.dart';
import 'ui/settings_view.dart';
import 'ui/toast_slide.dart';
import 'ui/theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // The drive-away overlay is a second engine running this same entrypoint.
  if (args.firstOrNull == 'multi_window') {
    runApp(const DriveAwayApp());
    return;
  }
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: toastSize,
    skipTaskbar: true,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
    title: 'Zip Break Buddy',
  );
  // The window stays hidden until a reminder fires.
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setResizable(false);
    await windowManager.setPreventClose(true);
  });

  final controller = AppController();
  await controller.init();
  runApp(ZipApp(controller: controller));
  // Dev shortcut: `flutter run ... --dart-entrypoint-args=--open-settings`.
  if (kZipDebug && args.contains('--open-settings')) {
    await controller.openSettings();
  }
  if (kZipDebug && args.contains('--test-drive')) {
    await controller.testDrive();
  }
}

class ZipApp extends StatelessWidget {
  const ZipApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zip Break Buddy',
      debugShowCheckedModeBanner: false,
      theme: buildZipTheme(),
      color: Colors.transparent,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListenableBuilder(
          listenable: Listenable.merge([
            controller.current,
            controller.settingsOpen,
          ]),
          builder: (context, _) {
            if (controller.settingsOpen.value) {
              return SettingsView(
                // Fresh state each time Settings opens or is saved.
                key: ObjectKey(controller.settings),
                initial: controller.settings,
                unitLabel: unitLabel,
                onSave: controller.saveSettings,
                onCancel: controller.closeSettings,
              );
            }
            final message = controller.current.value;
            if (message == null) return const SizedBox.shrink();
            return ColoredBox(
              // Practically invisible, but keeps the window painting while
              // the pop-up is off-screen, so the resize after showing
              // produces a real frame and Windows resizes the surface.
              color: const Color(0x01F6F2EA),
              child: ToastSlide(
                visible: controller.toastIn,
                // Crossfade when the message swaps in place (e.g. snooze).
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: ReminderToast(
                    key: ObjectKey(message),
                    message: message,
                    onDone: controller.done,
                    onSnooze: controller.snooze,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The overlay window's app: draws Zip driving off when the main window
/// sends 'drive', and answers 'ping' so the main window knows it is ready.
class DriveAwayApp extends StatefulWidget {
  const DriveAwayApp({super.key});

  @override
  State<DriveAwayApp> createState() => _DriveAwayAppState();
}

class _DriveAwayAppState extends State<DriveAwayApp>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(
    vsync: this,
    duration: driveAwayDuration,
  );

  @override
  void initState() {
    super.initState();
    WindowController.fromCurrentEngine().then(
      (window) => window.setWindowMethodHandler((call) async {
        switch (call.method) {
          case 'drive':
            await _progress.forward(from: 0);
          case 'ping':
            break;
        }
        return null;
      }),
    );
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: DriveAwayView(progress: _progress),
      ),
    );
  }
}
