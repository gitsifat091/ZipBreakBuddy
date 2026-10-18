import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays Zip's two generated sounds (see `tool/generate_sounds.dart`).
/// Failures are logged and swallowed: a missing audio device must never
/// break a reminder.
class SoundPlayer {
  static const _pipVolume = 0.5;
  static const _vroomVolume = 0.6;

  final _pip = AudioPlayer();
  final _vroom = AudioPlayer();

  Future<void> pipPip() => _play(_pip, 'sounds/pip_pip.wav', _pipVolume);

  Future<void> vroom() => _play(_vroom, 'sounds/vroom.wav', _vroomVolume);

  Future<void> _play(AudioPlayer player, String asset, double volume) async {
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('[Zip] could not play $asset: $e');
    }
  }

  Future<void> dispose() async {
    await _pip.dispose();
    await _vroom.dispose();
  }
}
