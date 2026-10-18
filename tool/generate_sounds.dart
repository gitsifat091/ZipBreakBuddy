// Synthesizes Zip's two sounds from scratch, so the repo ships no third-party
// audio. Plain Dart, no Flutter needed:
//
//   dart run tool/generate_sounds.dart
//
// Writes 16-bit mono WAV files to assets/sounds/:
//   pip_pip.wav  two short, friendly car-horn beeps (about 0.45 s)
//   vroom.wav    an engine that revs up strong and fades as Zip drives off
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _sampleRate = 44100;
const _outDir = 'assets/sounds';

void main() {
  Directory(_outDir).createSync(recursive: true);
  _writeWav('$_outDir/pip_pip.wav', _pipPip());
  _writeWav('$_outDir/vroom.wav', _vroom());
}

/// Two beeps of a small horn: a pair of close tones (a major third, like a
/// real two-tone horn) with a touch of buzz from the odd harmonics.
Float64List _pipPip() {
  const beep = 0.14;
  const gap = 0.07;
  const total = beep * 2 + gap + 0.05;
  final out = Float64List((total * _sampleRate).round());
  for (final start in [0.0, beep + gap]) {
    final from = (start * _sampleRate).round();
    final length = (beep * _sampleRate).round();
    for (var i = 0; i < length; i++) {
      final t = i / _sampleRate;
      final envelope = _envelope(t, beep, attack: 0.008, release: 0.035);
      var tone = 0.0;
      for (final f in const [660.0, 830.0]) {
        tone += math.sin(2 * math.pi * f * t);
        tone += 0.28 * math.sin(2 * math.pi * f * 3 * t);
        tone += 0.12 * math.sin(2 * math.pi * f * 5 * t);
      }
      out[from + i] += tone * envelope * 0.3;
    }
  }
  return out;
}

/// A little engine: a sawtooth whose pitch swoops up and settles, chopped by
/// a cylinder-like pulse, over low rumble noise. Loudest at the start, then
/// it fades out over 2.6 s as the car leaves.
Float64List _vroom() {
  const total = 2.6;
  final out = Float64List((total * _sampleRate).round());
  final random = math.Random(7);
  var phase = 0.0;
  var rumble = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / _sampleRate;
    final progress = t / total;
    // Rev up quickly, then ease back down as the car pulls away.
    final rev = progress < 0.25
        ? 70 + 130 * math.sin(progress / 0.25 * math.pi / 2)
        : 200 - 90 * ((progress - 0.25) / 0.75);
    phase += 2 * math.pi * rev / _sampleRate;
    final saw = 2 * ((phase / (2 * math.pi)) % 1) - 1;
    final body = saw * 0.6 + math.sin(phase * 2) * 0.3;
    final pulse = 0.75 + 0.25 * math.sin(phase * 0.5);
    rumble += 0.08 * ((random.nextDouble() * 2 - 1) - rumble); // low-pass
    final fade = math.pow(1 - progress, 1.6).toDouble();
    final attack = math.min(1.0, t / 0.03);
    final sample = (body * pulse + rumble * 1.6) * fade * attack;
    out[i] = _softClip(sample * 1.3) * 0.8;
  }
  return out;
}

double _envelope(
  double t,
  double length, {
  required double attack,
  required double release,
}) => math.min(1.0, math.min(t / attack, (length - t) / release));

double _softClip(double x) {
  final e = math.exp(2 * x);
  return (e - 1) / (e + 1);
}

void _writeWav(String path, Float64List samples) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, _sampleRate, Endian.little);
  data.setUint32(28, _sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(
      44 + i * 2,
      (samples[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  File(path).writeAsBytesSync(data.buffer.asUint8List());
  stdout.writeln(
    'wrote $path (${(samples.length / _sampleRate).toStringAsFixed(2)} s)',
  );
}
