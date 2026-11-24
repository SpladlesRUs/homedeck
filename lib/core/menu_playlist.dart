/// Ordered Wii U-style home-menu playlist. Playback starts at a random index
/// then walks forward and wraps. RNG is injected so start-index is unit-tested.
class MenuPlaylist {
  MenuPlaylist._();

  static const assetDirectory = 'assets/audio/music';

  static const titles = <String>[
    'Cozy Console Menu',
    'Cozy Console Menu (take 2)',
    'Cozy Rainy Afternoon',
    'Cozy Rainy Afternoon (take 2)',
    'Sunny Plaza Menu',
    'Plaza Morning',
    'Browsing Menu',
    'Cozy Menu Groove',
    'Menu of Tomorrow',
    'Save Game',
  ];

  static String titleAt(int index) {
    if (titles.isEmpty) {
      return 'Menu music';
    }
    final i = index % titles.length;
    return titles[i < 0 ? 0 : i];
  }

  static const tracks = <String>[
    '$assetDirectory/menu-01.m4a',
    '$assetDirectory/menu-02.m4a',
    '$assetDirectory/menu-03.m4a',
    '$assetDirectory/menu-04.m4a',
    '$assetDirectory/menu-05.m4a',
    '$assetDirectory/menu-06.m4a',
    '$assetDirectory/menu-07.m4a',
    '$assetDirectory/menu-08.m4a',
    '$assetDirectory/menu-09.m4a',
    '$assetDirectory/menu-10.m4a',
  ];

  /// [randomInt] must return `0..max-1`, matching [Random.nextInt].
  static int startIndex({
    required int length,
    required int Function(int max) randomInt,
  }) {
    if (length <= 0) {
      return 0;
    }
    final pick = randomInt(length);
    if (pick < 0) {
      return 0;
    }
    if (pick >= length) {
      return length - 1;
    }
    return pick;
  }

  static int nextIndex(int current, int length) {
    if (length <= 0) {
      return 0;
    }
    return (current + 1) % length;
  }

  /// audioplayers [AssetSource] paths omit the `assets/` prefix.
  static String playerAsset(String flutterAsset) {
    const prefix = 'assets/';
    if (flutterAsset.startsWith(prefix)) {
      return flutterAsset.substring(prefix.length);
    }
    return flutterAsset;
  }
}
