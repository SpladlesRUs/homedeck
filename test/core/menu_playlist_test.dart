import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/menu_playlist.dart';

void main() {
  test('startIndex uses the injected RNG and stays in range', () {
    expect(MenuPlaylist.startIndex(length: 10, randomInt: (max) => 0), 0);
    expect(
      MenuPlaylist.startIndex(
        length: 10,
        randomInt: (max) {
          expect(max, 10);
          return 7;
        },
      ),
      7,
    );
    expect(MenuPlaylist.startIndex(length: 10, randomInt: (max) => 9), 9);
    expect(MenuPlaylist.startIndex(length: 10, randomInt: (max) => 99), 9);
    expect(MenuPlaylist.startIndex(length: 0, randomInt: (max) => 3), 0);
  });

  test('nextIndex walks forward and wraps to the start', () {
    expect(MenuPlaylist.nextIndex(0, 10), 1);
    expect(MenuPlaylist.nextIndex(8, 10), 9);
    expect(MenuPlaylist.nextIndex(9, 10), 0);
    expect(MenuPlaylist.nextIndex(0, 1), 0);
    expect(MenuPlaylist.nextIndex(4, 0), 0);
  });

  test(
    'playlist has ten instrumental tracks and strips assets/ for the player',
    () {
      expect(MenuPlaylist.tracks, hasLength(10));
      expect(MenuPlaylist.tracks.first, 'assets/audio/music/menu-01.m4a');
      expect(MenuPlaylist.tracks.last, 'assets/audio/music/menu-10.m4a');
      expect(
        MenuPlaylist.playerAsset(MenuPlaylist.tracks[3]),
        'audio/music/menu-04.m4a',
      );
    },
  );
}
