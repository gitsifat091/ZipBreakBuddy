import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The whole animation. Zip is gone by [_driveFraction] of it; the rest lets
/// the last smoke puffs fade out.
const driveAwayDuration = Duration(milliseconds: 3000);
const _driveFraction = 0.77;

const _carWidth = 170.0;
const _scale = _carWidth / 260; // The SVG is 260x165.
const _carHeight = 165 * _scale;
const _wheelRadius = 21 * _scale;
const _groundGap = 8.0; // Wheels sit this far above the strip's bottom.
const _puffInterval = 0.06; // Seconds between smoke puffs.
const _puffLife = 0.8;
const _smoke = Color(0xFF8E959C);

/// Zip driving from the bottom-right to off the left edge. Everything is a
/// pure function of [progress] (0..1), so it is easy to test and scrub.
class DriveAwayView extends StatelessWidget {
  const DriveAwayView({super.key, required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: progress,
        builder: (context, _) => _scene(box.biggest, progress.value),
      ),
    );
  }

  Widget _scene(Size size, double t) {
    final seconds = _seconds(t);
    final left = _carLeft(size.width, t);
    final top = _carTop(size.height);
    final bounce =
        -2.5 * math.sin(seconds * 2 * math.pi * 6.5).abs() +
        0.6 * math.sin(seconds * 2 * math.pi * 11);
    final tilt = 0.012 * math.sin(seconds * 2 * math.pi * 5);
    final spin = -(_carLeft(size.width, 0) - left) / _wheelRadius;

    return ColoredBox(
      // Practically invisible, but keeps the window painting (see main.dart).
      color: const Color(0x01F6F2EA),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _SmokePainter(progress: t)),
          ),
          Positioned(
            left: left,
            top: top + bounce,
            width: _carWidth,
            height: _carHeight,
            child: Transform.rotate(
              angle: tilt,
              child: Stack(
                children: [
                  Transform.flip(
                    flipX: true,
                    child: SvgPicture.asset(
                      'assets/zip/zip_drive.svg',
                      width: _carWidth,
                    ),
                  ),
                  // Wheel centres, mirrored along with the body.
                  for (final x in const [70.0, 186.0])
                    Positioned(
                      left: x * _scale - _wheelRadius,
                      top: 126 * _scale - _wheelRadius,
                      child: CustomPaint(
                        size: Size.square(_wheelRadius * 2),
                        painter: _WheelPainter(spin),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _seconds(double t) => t * driveAwayDuration.inMilliseconds / 1000;

/// The car's left edge: starts near the right edge (where the pop-up sat),
/// accelerates and leaves fully past the left edge.
double _carLeft(double width, double t) {
  final start = width - _carWidth - 24;
  final end = -_carWidth - 20;
  final drive = (t / _driveFraction).clamp(0.0, 1.0);
  return start + (end - start) * Curves.easeInQuad.transform(drive);
}

/// Top of the car so the wheels rest [_groundGap] above the bottom edge.
double _carTop(double height) => height - _groundGap - (126 + 21) * _scale;

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.angle);

  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1E2A3A));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawCircle(
      Offset.zero,
      r * 0.38,
      Paint()..color = const Color(0xFFE7E2D8),
    );
    final lug = Paint()..color = const Color(0xFF8A93A0);
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      canvas.drawCircle(
        Offset(math.cos(a), math.sin(a)) * r * 0.66,
        r * 0.1,
        lug,
      );
    }
    canvas.drawLine(
      Offset(-r * 0.3, 0),
      Offset(r * 0.3, 0),
      Paint()
        ..color = const Color(0xFF8A93A0)
        ..strokeWidth = r * 0.14
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.angle != angle;
}

/// Grey puffs from the exhaust. They stay where they were emitted, so the
/// car leaves a trail that grows, drifts up and fades.
class _SmokePainter extends CustomPainter {
  _SmokePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final now = _seconds(progress);
    // The tailpipe: bottom-right of the flipped car.
    final pipeY = _carTop(size.height) + 119 * _scale;
    final driveEnd = _seconds(_driveFraction);
    for (
      var born = 0.0;
      born <= math.min(now, driveEnd);
      born += _puffInterval
    ) {
      final age = now - born;
      if (age > _puffLife) continue;
      final bornT = born / (driveAwayDuration.inMilliseconds / 1000);
      final x = _carLeft(size.width, bornT) + 234 * _scale;
      final life = age / _puffLife;
      final center = Offset(x + age * 26, pipeY - age * 34 - age * age * 14);
      final alpha = 0.65 * math.pow(1 - life, 1.3).toDouble();
      final paint = Paint()..color = _smoke.withValues(alpha: alpha);
      final radius = 4 + age * 24;
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(
        center + Offset(radius * 0.5, -radius * 0.3),
        radius * 0.65,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) => old.progress != progress;
}
