import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:homedeck/core/generated_icon.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/library_groups.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/audio_prefs.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:homedeck/core/models/home_layout.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/models/tile_layout.dart';
import 'package:homedeck/core/placeholder_png.dart';
import 'package:homedeck/core/preferences_repository.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/rom_library.dart';
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

  /// Serializes disk writes. Ally Phase2 at 4996779 saw `apps=[]` at close
  /// after successful adds because overlapping `_commit`s built from a stale
  /// empty `_state` (window/audio prefs) finished after the add write.
  Future<void> _writeChain = Future<void>.value();
  int _commitGeneration = 0;

  bool get isLoaded => _loaded;

  HomeDeckState get state => _state;

  /// Full library, in library order. Not the Home desktop.
  List<AppRecord> get apps => _state.orderedApps;

  HomeLayout get home => _state.home;

  AppPlatform get hostPlatform => _adapter.platform;

  List<String?> homeSlots({required int minLength}) =>
      _state.home.padded(minLength);

  bool isOnHome(String id) => _state.home.contains(id);

  List<LibrarySection> librarySections(LibraryGroupMode mode) =>
      groupLibrary(apps, mode: mode);

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

  Future<AppRecord?> addFromPicker({bool pinToHome = true}) async {
    final picked = await _adapter.pickLaunchTarget();
    if (picked == null) {
      return null;
    }
    // pinToHome defaults true so Ally Phase2 (SendKeys 'a' → Open → Add to
    // HomeDeck) leaves a Home pin Enter can launch without a second Confirm.
    final record = await addRecord(
      displayName: picked.displayName,
      target: picked.target,
      kind: picked.kind,
      pinToHome: pinToHome,
    );
    // Refuse "success" without a durable tile PNG (Ally false PASS with
    // apps=[] / only _homedeck_ready.png).
    final tile = _icons.absoluteFile(record.iconRef) ??
        _icons.absoluteFile('icons/${record.id}.png');
    if (tile == null) {
      await _icons.writePng(record.id, placeholderPng);
      final again = _icons.absoluteFile('icons/${record.id}.png');
      if (again == null) {
        throw StateError(
          'addFromPicker produced no icons/${record.id}.png',
        );
      }
    }
    return record;
  }

  Future<String?> pickFile({
    required String label,
    required List<String> extensions,
  }) {
    return _adapter.pickFile(label: label, extensions: extensions);
  }

  /// Platform Steam library scan on Windows.
  Future<List<DiscoveredApp>> discoverInstalled() => _adapter.discover();

  /// Platform Start Menu Programs scan on Windows.
  Future<List<DiscoveredApp>> discoverStartMenu() =>
      _adapter.discoverStartMenu();

  /// Platform ROM-folder scan on Windows.
  Future<List<DiscoveredApp>> discoverRoms() => _adapter.discoverRoms(
        romRoot: _state.romRoot,
        emulator: resolveRomEmulator(),
      );

  /// Platform Epic Games Launcher manifest scan on Windows.
  Future<List<DiscoveredApp>> discoverEpic() => _adapter.discoverEpic();

  /// Adds discovered apps that are not already in the library. Does not pin
  /// to Home — Library / By app holds them.
  ///
  /// Dedupes native / URI / shortcut tiles by launch [LaunchTarget.value], and
  /// emulated tiles by [LaunchTarget.romPath] so multiple ROMs sharing one
  /// emulator (or an empty emulator) still import.
  ///
  /// [discover] defaults to Steam ([PlatformAdapter.discover]); use
  /// [importStartMenu] / [importRoms] / [importEpic] for the other scanners.
  Future<int> importDiscovered({
    bool pinToHome = false,
    Future<List<DiscoveredApp>> Function()? discover,
  }) async {
    final found = await (discover ?? _adapter.discover)();
    if (found.isEmpty) {
      return 0;
    }
    final existing = <String>{};
    for (final app in apps) {
      for (final target in app.targets.values) {
        final key = _importDedupeKey(
          kind: app.kind,
          target: target,
        );
        if (key.isNotEmpty) {
          existing.add(key);
        }
      }
    }
    var added = 0;
    for (final discovery in found) {
      final key = _importDedupeKey(
        kind: discovery.kind,
        target: discovery.target,
      );
      if (key.isEmpty || existing.contains(key)) {
        continue;
      }
      await addRecord(
        displayName: discovery.displayName,
        target: discovery.target,
        kind: discovery.kind,
        pinToHome: pinToHome,
      );
      existing.add(key);
      added++;
    }
    return added;
  }

  /// Start Menu Programs discover → same import path as Steam (no Home pins).
  Future<int> importStartMenu({bool pinToHome = false}) {
    return importDiscovered(
      pinToHome: pinToHome,
      discover: _adapter.discoverStartMenu,
    );
  }

  /// ROM-folder discover → Library emulated tiles (no Home pins).
  Future<int> importRoms({bool pinToHome = false}) {
    return importDiscovered(
      pinToHome: pinToHome,
      discover: discoverRoms,
    );
  }

  /// Epic Games Launcher discover → Library native tiles (no Home pins).
  Future<int> importEpic({bool pinToHome = false}) {
    return importDiscovered(
      pinToHome: pinToHome,
      discover: _adapter.discoverEpic,
    );
  }

  /// Persist the Settings-chosen ROM folder (Ally may override via env).
  Future<void> setRomRoot(String? path) async {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await _commit((state) => state.copyWith(clearRomRoot: true));
      return;
    }
    await _commit(
      (state) => state.copyWith(romRoot: WindowsPaths.normalize(trimmed)),
    );
  }

  /// Emulator for ROM imports: `HOMEDECK_EMULATOR`, else the single obvious
  /// emulator `.exe` already on an emulated library tile, else null/empty.
  String? resolveRomEmulator() {
    final fromEnv = RomFolderScanner.defaultEmulatorPath();
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return _singleLibraryEmulator();
  }

  /// When exactly one distinct non-empty emulator path exists among emulated
  /// library tiles, reuse it. No console taxonomy — ambiguous → leave unset.
  String? _singleLibraryEmulator() {
    final found = <String, String>{};
    for (final app in apps) {
      if (app.kind != TileKind.emulated) {
        continue;
      }
      for (final target in app.targets.values) {
        if (target.kind != LaunchTargetKind.windowsEmulated) {
          continue;
        }
        final raw = target.value.trim();
        if (raw.isEmpty) {
          continue;
        }
        final normalized = WindowsPaths.normalize(raw);
        found.putIfAbsent(normalized.toLowerCase(), () => normalized);
      }
    }
    if (found.length != 1) {
      return null;
    }
    return found.values.single;
  }

  static String _importDedupeKey({
    required TileKind kind,
    required LaunchTarget target,
  }) {
    if (kind == TileKind.emulated || target.isEmulated) {
      final rom = target.romPath?.trim() ?? '';
      if (rom.isNotEmpty) {
        return 'rom:${rom.toLowerCase()}';
      }
    }
    return target.value.trim().toLowerCase();
  }

  Future<AppRecord> addRecord({
    required String displayName,
    required LaunchTarget target,
    TileKind kind = TileKind.native,
    ConsoleSystem? console,
    Storefront? store,
    String? category,
    bool favorite = false,
    bool pinToHome = false,
    int? homeSlot,
  }) async {
    final id = _idFactory();
    // Guarantee a PNG under icons\ before platform resolve (Ally 10fe4ac
    // saw empty icons\ when resolveIcon stalled in dart:ui / extract).
    await _icons.writePng(id, placeholderPng);
    final iconRef = await _adapter.resolveIcon(
      target: target,
      cache: _icons,
      appId: id,
      displayName: displayName,
    );
    final resolvedConsole = kind == TileKind.emulated
        ? (console ?? SourceInference.consoleFor(target))
        : null;
    final resolvedStore = kind == TileKind.native
        ? (store ?? SourceInference.storeFor(target))
        : null;
    final record = AppRecord(
      id: id,
      displayName: displayName,
      iconRef: iconRef,
      position: apps.length,
      category: category,
      favorite: favorite,
      kind: kind,
      console: resolvedConsole,
      store: resolvedStore,
      targets: {target.platform: target},
    );
    // Capture pin/home against the latest state inside the write queue so a
    // concurrent window/audio prefs commit cannot overwrite the new tile.
    await _commit((state) {
      var home = state.home;
      if (pinToHome) {
        home = home.pinning(id, at: homeSlot);
      }
      return state.copyWith(
        apps: List<AppRecord>.unmodifiable([...state.apps, record]),
        layout: state.layout.placing(id),
        home: home,
      );
    });
    return record;
  }

  Future<void> pinToHome(String id, {int? at}) async {
    if (byId(id) == null) {
      return;
    }
    await _commit((state) => state.copyWith(home: state.home.pinning(id, at: at)));
  }

  Future<void> unpinFromHome(String id) async {
    await _commit((state) => state.copyWith(home: state.home.unpinning(id)));
  }

  Future<void> remove(String id) async {
    await _commit(
      (state) => state.copyWith(
        apps: List<AppRecord>.unmodifiable(
          state.apps.where((app) => app.id != id),
        ),
        layout: state.layout.removing(id),
        home: state.home.unpinning(id),
      ),
    );
  }

  Future<void> reorder(int from, int to) async {
    await _commit(
      (state) => state.copyWith(layout: state.layout.reordering(from, to)),
    );
  }

  Future<void> moveHomeSlot(
    int from,
    TraversalDirection direction,
    int columns,
  ) async {
    await _commit(
      (state) =>
          state.copyWith(home: state.home.moving(from, direction, columns)),
    );
  }

  Future<void> swapHomeSlots(int from, int to) async {
    await _commit(
      (state) => state.copyWith(home: state.home.swapping(from, to)),
    );
  }

  Future<void> toggleFavorite(String id) async {
    await _commit((state) {
      final next = state.apps
          .map(
            (app) => app.id == id ? app.copyWith(favorite: !app.favorite) : app,
          )
          .toList(growable: false);
      return state.copyWith(apps: List<AppRecord>.unmodifiable(next));
    });
  }

  Future<void> setWindowPrefs(WindowPrefs prefs) async {
    await _commit((state) => state.copyWith(window: prefs));
  }

  Future<void> setAudioPrefs(AudioPrefs prefs) async {
    await _commit((state) => state.copyWith(audio: prefs));
  }

  Future<void> _commit(HomeDeckState Function(HomeDeckState state) update) {
    // Publish in-memory immediately so one `tester.pump()` sees pins/unpins.
    // Queue a disk write of the *live* `_state` (not this commit's snapshot):
    // Ally @9800850 still saw apps=[] at close because a queued window/audio
    // prefs write held an empty snapshot captured before add and landed last.
    final prior = _state;
    final next = update(_state);
    final generation = ++_commitGeneration;
    _state = next;
    notifyListeners();
    final done = _writeChain.catchError((_) {}).then((_) async {
      try {
        await _preferences.save(_state);
        // Ally b630dc3: ready marker on disk but no per-tile PNG after add.
        for (final app in _state.apps) {
          final existing =
              _icons.absoluteFile(app.iconRef ?? 'icons/${app.id}.png');
          if (existing == null) {
            try {
              await _icons.writePng(app.id, placeholderPng);
            } catch (_) {
              // Best-effort; library.json already saved.
            }
          }
        }
      } catch (error) {
        if (generation == _commitGeneration) {
          _state = prior;
          notifyListeners();
        }
        throw error;
      }
    });
    _writeChain = done.catchError((_) {});
    return done;
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
    for (final app in _state.apps) {
      if (app.id == id) {
        return app;
      }
    }
    return null;
  }

  File? iconFile(AppRecord app) => _icons.absoluteFile(app.iconRef);

  Future<HomeDeckState> _buildDemoState() async {
    final records = <AppRecord>[];
    final ids = <String>[];
    final homeSlots = List<String?>.filled(24, null);
    for (var i = 0; i < _demoEntries.length; i++) {
      final entry = _demoEntries[i];
      final id = _idFactory();
      ids.add(id);
      final iconRef = await _icons.writePng(
        id,
        await generateInitialIcon(displayName: entry.name, key: id),
      );
      final target = await _demoTarget(entry);
      records.add(
        AppRecord(
          id: id,
          displayName: entry.name,
          iconRef: iconRef,
          position: i,
          favorite: i == 1,
          kind: entry.kind,
          console: entry.console,
          store: entry.store,
          targets: {AppPlatform.windows: target},
        ),
      );
      if (entry.homeSlot != null && entry.homeSlot! < homeSlots.length) {
        homeSlots[entry.homeSlot!] = id;
      }
    }
    return HomeDeckState(
      apps: List<AppRecord>.unmodifiable(records),
      layout: TileLayout(orderedIds: List<String>.unmodifiable(ids)),
      home: HomeLayout(slots: List<String?>.unmodifiable(homeSlots)),
    );
  }

  Future<LaunchTarget> _demoTarget(_DemoEntry entry) async {
    if (entry.uri != null) {
      return LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: entry.uri!,
      );
    }
    if (entry.kind == TileKind.emulated) {
      final emulator = await DemoTargetFiles.materialize(
        supportRoot: _icons.paths.supportRoot,
        fileName: '${entry.name} emu.exe',
      );
      final rom = await DemoTargetFiles.materialize(
        supportRoot: _icons.paths.supportRoot,
        fileName: entry.romFile ?? '${entry.name}.rom',
      );
      return LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsEmulated,
        value: emulator,
        romPath: rom,
        argsTemplate: '{rom}',
      );
    }
    final path = await DemoTargetFiles.materialize(
      supportRoot: _icons.paths.supportRoot,
      fileName: '${entry.name}.exe',
    );
    return LaunchTarget(
      platform: AppPlatform.windows,
      kind: LaunchTargetKind.windowsExecutable,
      value: path,
    );
  }
}

class _DemoEntry {
  const _DemoEntry(
    this.name, {
    this.kind = TileKind.native,
    this.store,
    this.console,
    this.uri,
    this.romFile,
    this.homeSlot,
  });

  final String name;
  final TileKind kind;
  final Storefront? store;
  final ConsoleSystem? console;
  final String? uri;
  final String? romFile;
  final int? homeSlot;
}

const _demoEntries = <_DemoEntry>[
  _DemoEntry('Arcade Cabinet', store: Storefront.other, homeSlot: 0),
  _DemoEntry(
    'Star Pilot',
    kind: TileKind.emulated,
    console: ConsoleSystem.n64,
    romFile: 'Star Pilot.z64',
    homeSlot: 2,
  ),
  _DemoEntry(
    'Photo Deck',
    store: Storefront.steam,
    uri: 'steam://rungameid/400',
    homeSlot: 3,
  ),
  _DemoEntry('Workshop', store: Storefront.other),
  _DemoEntry(
    'Music Box',
    kind: TileKind.emulated,
    console: ConsoleSystem.snes,
    romFile: 'Music Box.sfc',
    homeSlot: 5,
  ),
  _DemoEntry(
    'Racing Night',
    store: Storefront.epic,
    uri: 'com.epicgames.launcher://apps/race',
  ),
  _DemoEntry(
    'Puzzle Garden',
    kind: TileKind.emulated,
    console: ConsoleSystem.gamecube,
    romFile: 'Puzzle Garden.gcm',
    homeSlot: 8,
  ),
  _DemoEntry('Sketch Pad', store: Storefront.gog),
  _DemoEntry(
    'Film Reel',
    store: Storefront.xbox,
    uri: 'msxbox://game/?id=film',
    homeSlot: 10,
  ),
  _DemoEntry(
    'Weather Atlas',
    kind: TileKind.emulated,
    console: ConsoleSystem.ps2,
    romFile: 'Weather Atlas.iso',
  ),
  _DemoEntry(
    'Recipe Book',
    store: Storefront.ea,
    uri: 'origin://launch/recipe',
  ),
  _DemoEntry('Mail Drop', store: Storefront.battlenet, uri: 'battlenet://mail'),
  _DemoEntry('Browser', store: Storefront.other, homeSlot: 16),
  _DemoEntry('Calculator', store: Storefront.other),
  _DemoEntry('Notes', store: Storefront.other),
  _DemoEntry(
    'Star Chart',
    kind: TileKind.emulated,
    console: ConsoleSystem.nes,
    romFile: 'Star Chart.nes',
    homeSlot: 18,
  ),
  _DemoEntry(
    'Harbor Watch',
    kind: TileKind.emulated,
    console: ConsoleSystem.gba,
    romFile: 'Harbor Watch.gba',
  ),
  _DemoEntry(
    'Comet Run',
    store: Storefront.steam,
    uri: 'steam://rungameid/440',
    homeSlot: 20,
  ),
  _DemoEntry(
    'Paper Kite',
    kind: TileKind.emulated,
    console: ConsoleSystem.genesis,
    romFile: 'Paper Kite.md',
  ),
  _DemoEntry('Glacier', store: Storefront.ubisoft),
  _DemoEntry(
    'Drumline',
    kind: TileKind.emulated,
    console: ConsoleSystem.arcade,
    romFile: 'Drumline.zip',
  ),
  _DemoEntry('Lanterns', store: Storefront.other),
  _DemoEntry(
    'Meadow',
    kind: TileKind.emulated,
    console: ConsoleSystem.dreamcast,
    romFile: 'Meadow.gdi',
  ),
  _DemoEntry('Copper Mine', store: Storefront.other, homeSlot: 23),
];

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
