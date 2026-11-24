import 'package:flutter/widgets.dart';
import 'package:homedeck/app.dart';
import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/preferences_repository.dart';
import 'package:homedeck/core/native_window_mode.dart';
import 'package:homedeck/platform/select_adapter.dart';
import 'package:path_provider/path_provider.dart';

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
  );
  await controller.load();
  final windowMode = NativeWindowModeController();
  runApp(
    HomeDeckApp(
      controller: controller,
      windowMode: windowMode,
    ),
  );
}
