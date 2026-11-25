import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:homedeck/app.dart';
import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/menu_music.dart';
import 'package:homedeck/core/preferences_repository.dart';
import 'package:homedeck/core/native_window_mode.dart';
import 'package:homedeck/platform/select_adapter.dart';
import 'package:homedeck/platform/select_device.dart';
import 'package:homedeck/platform/select_menu_music.dart';
import 'package:homedeck/platform/windows_automation.dart';
import 'package:path_provider/path_provider.dart';

/// Off in release. Pass `--dart-define=HOMEDECK_SEED_DEMO=true` in debug/tests.
const seedDemo = bool.fromEnvironment('HOMEDECK_SEED_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final paths = AppPaths(support);
  final icons = IconCache(paths);
  final preferences = PreferencesRepository(paths);
  final controller = LibraryController(
    adapter: selectPlatformAdapter(),
    preferences: preferences,
    icons: icons,
    seedDemo: seedDemo,
  );
  await controller.load();
  // Ally diagnostic: env set before launch must land apps[] even if SendKeys
  // `a` never opens a picker (HOMEDECK_ADD_PATH was inert @82a5a20).
  await seedHomeDeckAddPath(controller);
  final windowMode = NativeWindowModeController();
  final music = MenuMusicController(
    player: selectMenuMusicPlayer(),
    randomInt: Random().nextInt,
    prefs: controller.state.audio,
    persist: controller.setAudioPrefs,
  );
  runApp(
    HomeDeckApp(
      controller: controller,
      windowMode: windowMode,
      gamepad: selectGamepadSource(),
      deviceStatus: selectDeviceStatus(),
      music: music,
    ),
  );
}
