import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:homedeck/core/menu_music.dart';

/// Windows (and other audioplayers backends) playlist sink.
///
/// Load/play failures stay inside this class; the controller treats them as
/// no-ops so a missing codec never blocks the UI.
class AudioplayersMenuMusicPlayer implements MenuMusicPlayer {
  AudioplayersMenuMusicPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    try {
      _player.setReleaseMode(ReleaseMode.stop);
      _player.setPlayerMode(PlayerMode.mediaPlayer);
    } catch (_) {}
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!_complete.isClosed) {
        _complete.add(null);
      }
    });
  }

  final AudioPlayer _player;
  final _complete = StreamController<void>.broadcast();
  StreamSubscription<void>? _completeSub;

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> playAsset(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _completeSub?.cancel();
    try {
      await _player.dispose();
    } catch (_) {}
    await _complete.close();
  }
}
