import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:homedeck/core/generated_icon.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_layout.dart';
import 'package:homedeck/core/preferences_repository.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

typedef IdFactory = String Function();

/// Shared library behavior. Widgets talk to this, never to a platform adapter.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required PlatformAdapter adapter,
    required PreferencesRepository preferences,
    required IconCache icons,
    IdFactory? idFactory,
    this.seedDemo = false,
  }) : _adapter = adapter,
       _preferences = preferences,
       _icons = icons,
       _idFactory = idFactory ?? const Uuid().v4;

  final PlatformAdapter _adapter;
  final PreferencesRepository _preferences;
  final IconCache _icons;
  final IdFactory _idFactory;

  /// Debug/test only. Release builds never pass true.
  final bool seedDemo;

  HomeDeckState _state = const HomeDeckState();
  bool _loaded = false;

  bool get isLoaded => _loaded;

  HomeDeckState get state => _state;

  List<AppRecord> get apps => _state.orderedApps;

  AppPlatform get hostPlatform => _adapter.platform;

  Future<void> load() async {
    await _icons.ensureReady();
    _state = await _preferences.load();
    if (seedDemo && _state.apps.isEmpty) {
      _state = await _buildDemoState();
      await _preferences.save(_state);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> persist() => _preferences.save(_state);

  Future<AppRecord?> addFromPicker() async {
    final picked = await _adapter.pickLaunchTarget();
    if (picked == null) {
      return null;
    }
    return addRecord(
      displayName: picked.displayName,
      target: picked.target,
    );
  }

  Future<AppRecord> addRecord({
    required String displayName,
    required LaunchTarget target,
    String? category,
    bool favorite = false,
  }) async {
    final id = _idFactory();
    final iconRef = await _adapter.resolveIcon(
      target: target,
      cache: _icons,
      appId: id,
      displayName: displayName,
    );
    final record = AppRecord(
      id: id,
      displayName: displayName,
      iconRef: iconRef,
      position: apps.length,
      category: category,
      favorite: favorite,
      targets: {target.platform: target},
    );
    final nextApps = [..._state.apps, record];
    _state = _state.copyWith(
      apps: List<AppRecord>.unmodifiable(nextApps),
      layout: _state.layout.placing(id),
    );
    await persist();
    notifyListeners();
    return record;
  }

  Future<void> remove(String id) async {
    _state = _state.copyWith(
      apps: List<AppRecord>.unmodifiable(
        _state.apps.where((app) => app.id != id),
      ),
      layout: _state.layout.removing(id),
    );
    await persist();
    notifyListeners();
  }

  Future<void> reorder(int from, int to) async {
    _state = _state.copyWith(layout: _state.layout.reordering(from, to));
    await persist();
    notifyListeners();
  }

  Future<void> moveFocused(
    String id,
    TraversalDirection direction,
    int columns,
  ) async {
    _state = _state.copyWith(
      layout: _state.layout.move(id, direction, columns),
    );
    await persist();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final next = _state.apps
        .map((app) => app.id == id ? app.copyWith(favorite: !app.favorite) : app)
        .toList(growable: false);
    _state = _state.copyWith(apps: List<AppRecord>.unmodifiable(next));
    await persist();
    notifyListeners();
  }

  Future<void> setWindowPrefs(WindowPrefs prefs) async {
    _state = _state.copyWith(window: prefs);
    await persist();
    notifyListeners();
  }

  Future<LaunchOutcome> launch(String id) async {
    AppRecord? app;
    for (final candidate in _state.apps) {
      if (candidate.id == id) {
        app = candidate;
        break;
      }
    }
    if (app == null) {
      return LaunchFailure.missingFile(
        detail: 'Tile is no longer in the library.',
      );
    }
    final target =
        app.targetFor(_adapter.platform) ?? app.targets[AppPlatform.windows];
    if (target == null) {
      return LaunchFailure.launchFailed(
        detail: 'This tile has no launch target for this device.',
      );
    }
    return _adapter.launch(target);
  }

  AppRecord? byId(String id) {
    for (final app in apps) {
      if (app.id == id) {
        return app;
      }
    }
    return null;
  }

  File? iconFile(AppRecord app) => _icons.absoluteFile(app.iconRef);

  Future<HomeDeckState> _buildDemoState() async {
    const samples = <String>[
      'Arcade Cabinet',
      'Star Pilot',
      'Photo Deck',
      'Workshop',
      'Music Box',
      'Racing Night',
      'Puzzle Garden',
      'Sketch Pad',
      'Film Reel',
      'Weather Atlas',
      'Recipe Book',
      'Mail Drop',
      'Browser',
      'Calculator',
      'Notes',
      'Star Chart',
      'Harbor Watch',
      'Comet Run',
      'Paper Kite',
      'Glacier',
      'Drumline',
      'Lanterns',
      'Meadow',
      'Copper Mine',
    ];
    final records = <AppRecord>[];
    final ids = <String>[];
    for (var i = 0; i < samples.length; i++) {
      final name = samples[i];
      final id = _idFactory();
      ids.add(id);
      final iconRef = await _icons.writePng(
        id,
        await generateInitialIcon(displayName: name, key: id),
      );
      final targetPath = await DemoTargetFiles.materialize(
        supportRoot: _icons.paths.supportRoot,
        fileName: '$name.exe',
      );
      records.add(
        AppRecord(
          id: id,
          displayName: name,
          iconRef: iconRef,
          position: i,
          favorite: i == 1,
          targets: {
            AppPlatform.windows: LaunchTarget(
              platform: AppPlatform.windows,
              kind: LaunchTargetKind.windowsExecutable,
              value: targetPath,
            ),
          },
        ),
      );
    }
    return HomeDeckState(
      apps: List<AppRecord>.unmodifiable(records),
      layout: TileLayout(orderedIds: List<String>.unmodifiable(ids)),
    );
  }
}

/// Placeholder files for debug/test demo tiles. Not used in release.
class DemoTargetFiles {
  static Future<String> materialize({
    required String supportRoot,
    required String fileName,
  }) async {
    final dir = Directory(p.join(supportRoot, 'demo_targets'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
    if (!await file.exists()) {
      await file.writeAsString('HomeDeck demo placeholder', flush: true);
    }
    return file.path;
  }
}
