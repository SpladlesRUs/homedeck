import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/audio_prefs.dart';
import 'package:homedeck/core/models/home_layout.dart';
import 'package:homedeck/core/models/tile_layout.dart';

/// Window chrome persisted with the library.
class WindowPrefs {
  const WindowPrefs({this.fullscreen = false, this.borderless = false});

  final bool fullscreen;
  final bool borderless;

  WindowPrefs copyWith({bool? fullscreen, bool? borderless}) {
    return WindowPrefs(
      fullscreen: fullscreen ?? this.fullscreen,
      borderless: borderless ?? this.borderless,
    );
  }

  Map<String, Object?> toJson() => {
    'fullscreen': fullscreen,
    'borderless': borderless,
  };

  factory WindowPrefs.fromJson(Map<String, Object?> json) {
    return WindowPrefs(
      fullscreen: json['fullscreen'] as bool? ?? false,
      borderless: json['borderless'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WindowPrefs &&
        other.fullscreen == fullscreen &&
        other.borderless == borderless;
  }

  @override
  int get hashCode => Object.hash(fullscreen, borderless);
}

/// Entire persisted HomeDeck library.
class HomeDeckState {
  const HomeDeckState({
    this.version = 1,
    this.apps = const [],
    this.layout = const TileLayout(),
    this.home = const HomeLayout(),
    this.window = const WindowPrefs(),
    this.audio = const AudioPrefs(),
    this.romRoot,
  });

  static const currentVersion = 1;

  final int version;
  final List<AppRecord> apps;
  final TileLayout layout;
  final HomeLayout home;
  final WindowPrefs window;
  final AudioPrefs audio;

  /// Absolute Windows folder scanned by ROM discovery (Settings picker).
  /// Overridden at scan time by `HOMEDECK_ROM_ROOT` when that env is set.
  final String? romRoot;

  List<AppRecord> get orderedApps {
    final byId = {for (final app in apps) app.id: app};
    final ordered = <AppRecord>[];
    for (final id in layout.orderedIds) {
      final app = byId.remove(id);
      if (app != null) {
        ordered.add(app);
      }
    }
    ordered.addAll(byId.values);
    return [
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(position: i),
    ];
  }

  HomeDeckState copyWith({
    int? version,
    List<AppRecord>? apps,
    TileLayout? layout,
    HomeLayout? home,
    WindowPrefs? window,
    AudioPrefs? audio,
    String? romRoot,
    bool clearRomRoot = false,
  }) {
    return HomeDeckState(
      version: version ?? this.version,
      apps: apps ?? this.apps,
      layout: layout ?? this.layout,
      home: home ?? this.home,
      window: window ?? this.window,
      audio: audio ?? this.audio,
      romRoot: clearRomRoot ? null : (romRoot ?? this.romRoot),
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'apps': apps.map((app) => app.toJson()).toList(growable: false),
    'layout': layout.toJson(),
    'home': home.toJson(),
    'window': window.toJson(),
    'audio': audio.toJson(),
    if (romRoot != null) 'romRoot': romRoot,
  };

  factory HomeDeckState.fromJson(Map<String, Object?> json) {
    final rawApps = json['apps'];
    final apps = <AppRecord>[];
    if (rawApps is List) {
      for (final entry in rawApps) {
        if (entry is Map) {
          apps.add(
            AppRecord.fromJson(
              entry.map((key, value) => MapEntry('$key', value)),
            ),
          );
        }
      }
    }
    final rawLayout = json['layout'];
    var layout = rawLayout is Map
        ? TileLayout.fromJson(
            rawLayout.map((key, value) => MapEntry('$key', value)),
          )
        : TileLayout(
            orderedIds: List<String>.unmodifiable(
              apps.map((app) => app.id).toList()..sort((a, b) {
                final left = apps.firstWhere((app) => app.id == a).position;
                final right = apps.firstWhere((app) => app.id == b).position;
                return left.compareTo(right);
              }),
            ),
          );
    if (layout.orderedIds.isEmpty && apps.isNotEmpty) {
      final sorted = [...apps]
        ..sort((a, b) => a.position.compareTo(b.position));
      layout = TileLayout(
        orderedIds: List<String>.unmodifiable(sorted.map((app) => app.id)),
      );
    }
    final rawHome = json['home'];
    var home = const HomeLayout();
    if (rawHome is Map) {
      home = HomeLayout.fromJson(
        rawHome.map((key, value) => MapEntry('$key', value)),
      );
    } else if (layout.orderedIds.isNotEmpty) {
      // Legacy library.json had a single packed layout that was Home.
      home = HomeLayout(slots: List<String?>.unmodifiable(layout.orderedIds));
    }
    final rawWindow = json['window'];
    final rawAudio = json['audio'];
    final rawRomRoot = json['romRoot'];
    return HomeDeckState(
      version: json['version'] as int? ?? currentVersion,
      apps: List<AppRecord>.unmodifiable(apps),
      layout: layout,
      home: home,
      window: rawWindow is Map
          ? WindowPrefs.fromJson(
              rawWindow.map((key, value) => MapEntry('$key', value)),
            )
          : const WindowPrefs(),
      audio: rawAudio is Map
          ? AudioPrefs.fromJson(
              rawAudio.map((key, value) => MapEntry('$key', value)),
            )
          : const AudioPrefs(),
      romRoot: rawRomRoot is String && rawRomRoot.trim().isNotEmpty
          ? rawRomRoot.trim()
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HomeDeckState &&
        other.version == version &&
        other.layout == layout &&
        other.home == home &&
        other.window == window &&
        other.audio == audio &&
        other.romRoot == romRoot &&
        _appsEqual(other.apps, apps);
  }

  @override
  int get hashCode => Object.hash(
    version,
    layout,
    home,
    window,
    audio,
    romRoot,
    Object.hashAll(apps),
  );
}

bool _appsEqual(List<AppRecord> a, List<AppRecord> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
