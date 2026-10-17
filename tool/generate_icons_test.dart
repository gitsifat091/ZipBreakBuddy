// Renders Zip into the app and tray icons. Not part of the test suite;
// run it on demand:  flutter test tool/generate_icons_test.dart
//
// Writes:
//   windows/runner/resources/app_icon.ico  (window, taskbar, .exe)
//   assets/tray_icon.ico                   (system tray)
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _background = Color(0xFFF6F2EA);
const _border = Color(0xFFE4DDD0);

/// The car's drawn area inside the 260x165 SVG viewBox (body, wheels,
/// spoiler and shadow), so the icon isn't mostly empty margin.
const _carBounds = Rect.fromLTRB(26, 42, 236, 158);

/// Tighter crop for the tiny tray icon: body and wheels only, so Zip is
/// as tall as possible at 16px.
const _trayBounds = Rect.fromLTRB(48, 42, 216, 148);

void main() {
  testWidgets('generate icons', (tester) async {
    await tester.runAsync(() async {
      final svg = await rootBundle.loadString('assets/zip/zip_happy.svg');
      final car = await vg.loadPicture(SvgStringLoader(svg), null);

      await _writeIco('windows/runner/resources/app_icon.ico',
          [for (final s in [16, 24, 32, 48, 64, 128, 256]) await _render(car.picture, s, badge: true)]);
      await _writeIco('assets/tray_icon.ico',
          [for (final s in [16, 20, 24, 32, 40, 48]) await _render(car.picture, s, badge: false)]);
      car.picture.dispose();
    });
  });
}

/// One square PNG. With [badge], Zip sits on a rounded cream tile (app
/// icon); without, Zip alone on transparent (tray, where space is tight).
Future<(int, Uint8List)> _render(ui.Picture car, int size, {required bool badge}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();

  if (badge) {
    final tile = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s).deflate(s * 0.02), Radius.circular(s * 0.22));
    canvas.drawRRect(tile, Paint()..color = _background);
    if (size >= 32) {
      canvas.drawRRect(
          tile,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.02
            ..color = _border);
    }
  }

  final bounds = badge ? _carBounds : _trayBounds;
  final fill = badge ? 0.84 : 1.0;
  final scale = s * fill / bounds.width;
  canvas
    ..translate((s - bounds.width * scale) / 2,
        (s - bounds.height * scale) / 2)
    ..scale(scale)
    ..translate(-bounds.left, -bounds.top)
    ..clipRect(bounds)
    ..drawPicture(car);

  final image = await recorder.endRecording().toImage(size, size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return (size, png!.buffer.asUint8List());
}

/// Packs PNG images into an .ico (PNG-compressed entries, Vista and later).
Future<void> _writeIco(String path, List<(int, Uint8List)> images) async {
  final header = ByteData(6 + 16 * images.length)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little) // type: icon
    ..setUint16(4, images.length, Endian.little);
  var offset = header.lengthInBytes;
  for (var i = 0; i < images.length; i++) {
    final (size, png) = images[i];
    final e = 6 + 16 * i;
    header
      ..setUint8(e, size >= 256 ? 0 : size) // 0 means 256
      ..setUint8(e + 1, size >= 256 ? 0 : size)
      ..setUint16(e + 4, 1, Endian.little) // color planes
      ..setUint16(e + 6, 32, Endian.little) // bits per pixel
      ..setUint32(e + 8, png.length, Endian.little)
      ..setUint32(e + 12, offset, Endian.little);
    offset += png.length;
  }
  final out = BytesBuilder()..add(header.buffer.asUint8List());
  for (final (_, png) in images) {
    out.add(png);
  }
  await File(path).writeAsBytes(out.toBytes());
  // ignore: avoid_print
  print('wrote $path (${images.map((i) => i.$1).join(', ')} px)');
}
