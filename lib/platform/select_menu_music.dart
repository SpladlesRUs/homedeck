import 'dart:io';

import 'package:homedeck/core/menu_music.dart';
import 'package:homedeck/platform/audioplayers_menu_music.dart';

/// Windows uses audioplayers. Any constructor/load failure is a silent player.
MenuMusicPlayer selectMenuMusicPlayer() {
  try {
    if (Platform.isWindows) {
      return AudioplayersMenuMusicPlayer();
    }
  } catch (_) {}
  return SilentMenuMusicPlayer();
}
