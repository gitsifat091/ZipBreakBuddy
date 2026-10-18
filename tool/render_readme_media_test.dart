// Renders the README screenshots and the slide-in GIF frames from the real
// app widgets, offscreen. Not part of the test suite; run on demand:
//
//   flutter test tool/render_readme_media_test.dart
//   ffmpeg -y -framerate 30 -i build/readme_frames/f_%03d.png \
//     -vf "split[a][b];[a]palettegen=reserve_transparent=0[p];[b][p]paletteuse" \
//     docs/slide-in.gif
//
// Uses the Windows system fonts (Segoe UI) so text matches the real app.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_break_buddy/core/app_settings.dart';
import 'package:zip_break_buddy/core/reminder.dart';
import 'package:zip_break_buddy/ui/reminder_toast.dart';
import 'package:zip_break_buddy/ui/settings_view.dart';
import 'package:zip_break_buddy/ui/theme.dart';
import 'package:zip_break_buddy/ui/toast_slide.dart';

const _shots = 'docs/screenshots';
const _frames = 'build/readme_frames';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(File(p).readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    const fonts = r'C:\Windows\Fonts';
    await _loadFont('Segoe UI', [
      '$fonts\\segoeui.ttf',
      '$fonts\\seguisb.ttf',
      '$fonts\\segoeuib.ttf',
    ]);
    // flutter_tester lives in <root>/bin/cache/artifacts/engine/<platform>/.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    await _loadFont('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
    Directory(_shots).createSync(recursive: true);
    Directory(_frames).createSync(recursive: true);
  });

  Widget app(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZipTheme(),
        home: Scaffold(backgroundColor: Colors.transparent, body: child),
      );

  /// Lets flutter_svg finish its async asset loads, then settles.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
  }

  Future<void> capture(WidgetTester tester, String path, {double ratio = 2}) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(path).writeAsBytes(png!.buffer.asUint8List());
    });
  }

  Future<void> sized(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  final toasts = {
    'posture': ReminderMessage.forType(ReminderType.posture),
    'eyes': ReminderMessage.forType(ReminderType.eyes),
    'water': ReminderMessage.forType(ReminderType.water),
    'break': ReminderMessage.forType(ReminderType.breakTime),
    'snoozed': ReminderMessage.snoozed,
    'pomodoro_focus': ReminderMessage.forType(ReminderType.pomodoroFocus),
  };

  for (final MapEntry(key: name, value: message) in toasts.entries) {
    testWidgets('toast $name', (tester) async {
      await sized(tester, const Size(380, 200));
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(RepaintBoundary(
        key: _shotKey,
        child: ReminderToast(message: message, onDone: () {}, onSnooze: () {}),
      )));
      await settle(tester);
      await capture(tester, '$_shots/toast_$name.png');
    });
  }

  testWidgets('settings', (tester) async {
    // The real 500x700 window; the settings fit with no scrolling.
    await sized(tester, const Size(500, 700));
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(RepaintBoundary(
      key: _shotKey,
      child: SettingsView(
        initial: AppSettings.defaults,
        unitLabel: 'min',
        onSave: (_) {},
        onCancel: () {},
      ),
    )));
    await settle(tester);
    await capture(tester, '$_shots/settings.png');
  });

  testWidgets('slide-in frames', (tester) async {
    // A bottom-right corner of a desktop: wallpaper, taskbar, the pop-up.
    const scene = Size(560, 300);
    await sized(tester, scene);
    addTearDown(tester.view.reset);
    final visible = ValueNotifier(false);
    await tester.pumpWidget(app(RepaintBoundary(
      key: _shotKey,
      child: Stack(children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFCFE0EE), Color(0xFFE9DCCB)],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0, right: 0, bottom: 0, height: 40,
          child: ColoredBox(color: Color(0xF2202A36)),
        ),
        Positioned(
          right: 16, bottom: 40 + 16, width: 380, height: 200,
          // The real window clips the pop-up to its 380x200 bounds.
          child: ClipRect(
            child: ToastSlide(
              visible: visible,
              child: ReminderToast(
                message: ReminderMessage.forType(ReminderType.posture),
                onDone: () {},
                onSnooze: () {},
              ),
            ),
          ),
        ),
      ]),
    )));
    await settle(tester);

    const frame = Duration(milliseconds: 1000 ~/ 30);
    var n = 0;
    Future<void> record(int count) async {
      for (var i = 0; i < count; i++) {
        await capture(tester, '$_frames/f_${(n++).toString().padLeft(3, '0')}.png', ratio: 1);
        await tester.pump(frame);
      }
    }

    await record(12); // empty corner
    visible.value = true;
    await record(54); // slide in (~0.42s) and hold
    visible.value = false;
    await record(18); // slide out (~0.24s) and pause before the loop
  });
}

const _shotKey = ValueKey('shot');
