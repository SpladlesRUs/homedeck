import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:homedeck/core/menu_playlist.dart';
import 'package:homedeck/core/models/audio_prefs.dart';

/// Platform playback. Implementations must not throw to the UI.
abstract class MenuMusicPlayer {
  Future<void> playAsset(String asset);

  Future<void> setVolume(double volume);

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();

  Future<void> dispose();

  Stream<void> get onComplete;
}

/// Test double / fallback when native audio cannot load.
class SilentMenuMusicPlayer implements MenuMusicPlayer {
  SilentMenuMusicPlayer();

  final plays = <String>[];
  final volumes = <double>[];
  var pauseCount = 0;
  var resumeCount = 0;
  var stopCount = 0;
  var disposeCount = 0;
  final _complete = StreamController<void>.broadcast();

  void emitComplete() => _complete.add(null);

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> playAsset(String asset) async {
    plays.add(asset);
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
  }

  @override
  Future<void> resume() async {
    resumeCount += 1;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  @override
  Future<void> dispose() async {
    disposeCount += 1;
    await _complete.close();
  }
}

/// Playlist runner: random start, sequential wrap, fade, duck, silent failures.
class MenuMusicController extends ChangeNotifier {
  MenuMusicController({
    required MenuMusicPlayer player,
    required int Function(int max) randomInt,
    this.tracks = MenuPlaylist.tracks,
    AudioPrefs prefs = const AudioPrefs(),
    this.fadeIn = const Duration(milliseconds: 800),
    this.fadeOut = const Duration(milliseconds: 400),
    Future<void> Function(AudioPrefs prefs)? persist,
  }) : _player = player,
       _randomInt = randomInt,
       _prefs = prefs,
       _persist = persist;

  final MenuMusicPlayer _player;
  final int Function(int max) _randomInt;
  final List<String> tracks;
  final Duration fadeIn;
  final Duration fadeOut;
  final Future<void> Function(AudioPrefs prefs)? _persist;

  AudioPrefs _prefs;
  int _index = 0;
  var _started = false;
  var _ducked = false;
  var _playing = false;
  var _disposed = false;
  Timer? _fade;
  StreamSubscription<void>? _completeSub;
  double _outputVolume = 0;

  AudioPrefs get prefs => _prefs;

  bool get musicEnabled => _prefs.musicEnabled;

  double get musicVolume => _prefs.musicVolume;

  int get currentIndex => _index;

  bool get isDucked => _ducked;

  Future<void> start() async {
    if (_disposed || _started) {
      return;
    }
    _started = true;
    _completeSub = _player.onComplete.listen((_) {
      unawaited(_onComplete());
    });
    if (!_prefs.musicEnabled || tracks.isEmpty) {
      return;
    }
    _index = MenuPlaylist.startIndex(
      length: tracks.length,
      randomInt: _randomInt,
    );
    await _playCurrent(fade: fadeIn);
  }

  Future<void> setEnabled(bool enabled) async {
    if (_prefs.musicEnabled == enabled) {
      return;
    }
    _prefs = _prefs.copyWith(musicEnabled: enabled);
    notifyListeners();
    await _save();
    if (!enabled) {
      await _fadeTo(0, fadeOut);
      await _safe(() => _player.pause());
      _playing = false;
      return;
    }
    if (_ducked) {
      return;
    }
    if (_playing) {
      await _safe(() => _player.resume());
      await _fadeTo(_prefs.musicVolume, fadeIn);
      return;
    }
    if (tracks.isEmpty) {
      return;
    }
    if (!_started) {
      await start();
      return;
    }
    await _playCurrent(fade: fadeIn);
  }

  Future<void> setVolume(double volume) async {
    final next = volume.clamp(0.0, 1.0);
    if (_prefs.musicVolume == next) {
      return;
    }
    _prefs = _prefs.copyWith(musicVolume: next);
    notifyListeners();
    await _save();
    if (!_prefs.musicEnabled || _ducked) {
      return;
    }
    _outputVolume = next;
    await _safe(() => _player.setVolume(next));
  }

  Future<void> duck() async {
    if (_disposed || _ducked) {
      return;
    }
    _ducked = true;
    await _fadeTo(0, fadeOut);
    await _safe(() => _player.pause());
  }

  Future<void> unduck() async {
    if (_disposed || !_ducked) {
      return;
    }
    _ducked = false;
    if (!_prefs.musicEnabled) {
      return;
    }
    await _safe(() => _player.resume());
    await _fadeTo(_prefs.musicVolume, fadeIn);
  }

  Future<void> fadeOutAndStop() async {
    await _fadeTo(0, fadeOut);
    await _safe(() => _player.stop());
    _playing = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _fade?.cancel();
    unawaited(_completeSub?.cancel());
    unawaited(_safe(() => _player.dispose()));
    super.dispose();
  }

  Future<void> _onComplete() async {
    if (_disposed || !_prefs.musicEnabled || tracks.isEmpty) {
      return;
    }
    _index = MenuPlaylist.nextIndex(_index, tracks.length);
    await _playCurrent(fade: Duration.zero);
  }

  Future<void> _playCurrent({required Duration fade}) async {
    final asset = tracks[_index];
    _playing = true;
    await _safe(() => _player.setVolume(0));
    _outputVolume = 0;
    await _safe(() => _player.playAsset(MenuPlaylist.playerAsset(asset)));
    if (_ducked || !_prefs.musicEnabled) {
      await _safe(() => _player.pause());
      _playing = false;
      return;
    }
    await _fadeTo(_prefs.musicVolume, fade);
  }

  Future<void> _fadeTo(double target, Duration duration) async {
    _fade?.cancel();
    final from = _outputVolume;
    if (duration <= Duration.zero || from == target) {
      _outputVolume = target;
      await _safe(() => _player.setVolume(target));
      return;
    }
    const steps = 8;
    final step = Duration(microseconds: duration.inMicroseconds ~/ steps);
    final completer = Completer<void>();
    var i = 0;
    _fade = Timer.periodic(step, (timer) {
      i += 1;
      final t = (i / steps).clamp(0.0, 1.0);
      final volume = from + (target - from) * t;
      _outputVolume = volume;
      unawaited(_safe(() => _player.setVolume(volume)));
      if (i >= steps) {
        timer.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    await completer.future;
  }

  Future<void> _save() async {
    final persist = _persist;
    if (persist == null) {
      return;
    }
    try {
      await persist(_prefs);
    } catch (_) {}
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}
