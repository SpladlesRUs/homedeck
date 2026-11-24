import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/menu_music.dart';
import 'package:homedeck/core/menu_playlist.dart';
import 'package:homedeck/core/models/audio_prefs.dart';

void main() {
  test('start plays a random track then wraps in order', () async {
    final player = SilentMenuMusicPlayer();
    final music = MenuMusicController(
      player: player,
      randomInt: (max) => 3,
      fadeIn: Duration.zero,
      fadeOut: Duration.zero,
    );
    await music.start();
    expect(music.currentIndex, 3);
    expect(player.plays, [MenuPlaylist.playerAsset(MenuPlaylist.tracks[3])]);

    player.emitComplete();
    await Future<void>.delayed(Duration.zero);
    expect(music.currentIndex, 4);
    expect(player.plays.last, MenuPlaylist.playerAsset(MenuPlaylist.tracks[4]));

    for (var i = 0; i < 6; i++) {
      player.emitComplete();
      await Future<void>.delayed(Duration.zero);
    }
    expect(music.currentIndex, 0);
    expect(player.plays.last, MenuPlaylist.playerAsset(MenuPlaylist.tracks[0]));
    music.dispose();
  });

  test('duck pauses and unduck resumes at the saved volume', () async {
    final player = SilentMenuMusicPlayer();
    final music = MenuMusicController(
      player: player,
      randomInt: (max) => 0,
      fadeIn: Duration.zero,
      fadeOut: Duration.zero,
    );
    await music.start();
    await music.duck();
    expect(music.isDucked, isTrue);
    expect(player.pauseCount, 1);
    expect(player.volumes.last, 0);
    await music.unduck();
    expect(music.isDucked, isFalse);
    expect(player.resumeCount, 1);
    expect(player.volumes.last, AudioPrefs.defaultMusicVolume);
    music.dispose();
  });

  test(
    'disabled music does not start and player errors are swallowed',
    () async {
      final player = _ThrowingPlayer();
      final music = MenuMusicController(
        player: player,
        randomInt: (max) => 0,
        prefs: const AudioPrefs(musicEnabled: false),
        fadeIn: Duration.zero,
        fadeOut: Duration.zero,
      );
      await music.start();
      expect(player.playAttempts, 0);
      await music.setEnabled(true);
      expect(player.playAttempts, 1);
      await music.duck();
      await music.unduck();
      await music.setVolume(0.5);
      await music.fadeOutAndStop();
      music.dispose();
    },
  );

  test('volume and enabled persist through the callback', () async {
    AudioPrefs? saved;
    final player = SilentMenuMusicPlayer();
    final music = MenuMusicController(
      player: player,
      randomInt: (max) => 0,
      fadeIn: Duration.zero,
      fadeOut: Duration.zero,
      persist: (prefs) async => saved = prefs,
    );
    await music.start();
    await music.setVolume(0.2);
    expect(saved?.musicVolume, 0.2);
    await music.setEnabled(false);
    expect(saved?.musicEnabled, isFalse);
    expect(player.pauseCount, greaterThan(0));
    music.dispose();
  });

  test('skipNext and togglePause notify and change playback', () async {
    final player = SilentMenuMusicPlayer();
    final music = MenuMusicController(
      player: player,
      randomInt: (max) => 0,
      fadeIn: Duration.zero,
      fadeOut: Duration.zero,
    );
    await music.start();
    expect(music.currentTitle, MenuPlaylist.titles.first);
    expect(music.isPlaying, isTrue);
    await music.togglePause();
    expect(music.isPlaying, isFalse);
    expect(player.pauseCount, 1);
    await music.togglePause();
    expect(music.isPlaying, isTrue);
    await music.skipNext();
    expect(music.currentIndex, 1);
    expect(music.currentTitle, MenuPlaylist.titles[1]);
    music.dispose();
  });
}

class _ThrowingPlayer implements MenuMusicPlayer {
  var playAttempts = 0;
  final _complete = StreamController<void>.broadcast();

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> playAsset(String asset) async {
    playAttempts += 1;
    throw StateError('no device');
  }

  @override
  Future<void> setVolume(double volume) async {
    throw StateError('no device');
  }

  @override
  Future<void> pause() async {
    throw StateError('no device');
  }

  @override
  Future<void> resume() async {
    throw StateError('no device');
  }

  @override
  Future<void> stop() async {
    throw StateError('no device');
  }

  @override
  Future<void> dispose() async {
    await _complete.close();
  }
}
