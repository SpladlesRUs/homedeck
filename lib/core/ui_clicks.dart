import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

enum UiClick { move, select, back, page }

/// Quiet, code-generated ticks. Never uses Suno clips.
/// [AudioPlayer] is created lazily so widget tests that keep clicks off
/// never touch the plugin.
class UiClickPlayer {
  UiClickPlayer({AudioPlayer? player, this.enabled = true}) : _player = player;

  AudioPlayer? _player;
  bool enabled;

  Future<void> play(UiClick kind) async {
    if (!enabled) {
      return;
    }
    try {
      final player = _player ??= AudioPlayer();
      final hz = switch (kind) {
        UiClick.move => 920,
        UiClick.select => 1280,
        UiClick.back => 640,
        UiClick.page => 1080,
      };
      await player.stop();
      await player.setVolume(0.18);
      await player.play(BytesSource(_tickWav(hz)));
    } catch (_) {}
  }

  Future<void> dispose() async {
    final player = _player;
    _player = null;
    if (player == null) {
      return;
    }
    try {
      await player.dispose();
    } catch (_) {}
  }
}

Uint8List tickWavForTest(int hz) => _tickWav(hz);

Uint8List _tickWav(int hz) {
  const sampleRate = 22050;
  const ms = 42;
  final n = (sampleRate * ms / 1000).round();
  final data = ByteData(44 + n * 2);
  void str(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final env = 1 - i / n;
    final sample = (0.12 * env * math.sin(2 * math.pi * hz * t) * 32767)
        .round();
    data.setInt16(44 + i * 2, sample.clamp(-32767, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}
