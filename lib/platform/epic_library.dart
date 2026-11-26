import 'dart:convert';
import 'dart:io';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:path/path.dart' as p;

/// Scans Epic Games Launcher manifests on Windows and emits [DiscoveredApp]
/// rows.
///
/// Roots come from optional `HOMEDECK_EPIC_ROOT` (Ally / CI fixture), the Epic
/// Games Launcher registry `AppDataPath`, then common
/// `%ProgramData%\Epic\EpicGamesLauncher\Data\Manifests` candidates. Each
/// `*.item` JSON supplies display name + launch target. Prefer
/// `com.epicgames.launcher://apps/…` when [AppName] (and ideally catalog ids)
/// are present; otherwise resolve `InstallLocation` + `LaunchExecutable`.
///
/// Does **not** invent games-only filtering — incomplete installs are skipped;
/// every other launchable manifest becomes a Library tile (By app → Epic).
class EpicLibraryScanner {
  EpicLibraryScanner({
    required WindowsIo io,
    List<String> Function()? candidateManifestRoots,
    Future<String?> Function()? registryAppDataPath,
    p.Context? pathContext,
  }) : _io = io,
       _candidateManifestRoots =
           candidateManifestRoots ?? defaultCandidateManifestRoots,
       _registryAppDataPath =
           registryAppDataPath ?? queryAppDataPathFromRegistry,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _candidateManifestRoots;
  final Future<String?> Function() _registryAppDataPath;
  final p.Context _path;

  /// Common Manifests folder guesses (no hard-coded drive letter).
  ///
  /// Optional `HOMEDECK_EPIC_ROOT` is tried first: either a folder of `*.item`
  /// files, or an Epic `Data` / launcher root that contains `Manifests/`.
  static List<String> defaultCandidateManifestRoots() {
    final env = Platform.environment;
    final out = <String>[];
    final path = WindowsPaths.context;
    final forced = env['HOMEDECK_EPIC_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      final normalized = WindowsPaths.normalize(forced);
      out.add(normalized);
      out.add(path.join(normalized, 'Manifests'));
      out.add(path.join(normalized, 'Data', 'Manifests'));
    }
    void addUnderProgramData(String? base) {
      if (base == null || base.trim().isEmpty) {
        return;
      }
      out.add(
        path.join(base, 'Epic', 'EpicGamesLauncher', 'Data', 'Manifests'),
      );
    }

    addUnderProgramData(env['ProgramData']);
    addUnderProgramData(env['PROGRAMDATA']);
    return out;
  }

  /// Reads HKLM / HKCU EpicGamesLauncher AppDataPath via `reg query`.
  static Future<String?> queryAppDataPathFromRegistry() async {
    if (!Platform.isWindows) {
      return null;
    }
    const queries = <List<String>>[
      [
        'query',
        r'HKLM\SOFTWARE\WOW6432Node\Epic Games\EpicGamesLauncher',
        '/v',
        'AppDataPath',
      ],
      [
        'query',
        r'HKLM\SOFTWARE\Epic Games\EpicGamesLauncher',
        '/v',
        'AppDataPath',
      ],
      [
        'query',
        r'HKCU\Software\Epic Games\EpicGamesLauncher',
        '/v',
        'AppDataPath',
      ],
    ];
    for (final args in queries) {
      try {
        final result = await Process.run('reg', args, runInShell: false);
        if (result.exitCode != 0) {
          continue;
        }
        final parsed = parseRegQueryAppDataPath('${result.stdout}');
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // Missing reg.exe or access denied — try next key / fall back to FS.
      }
    }
    return null;
  }

  /// Pulls the REG_SZ data column from a `reg query` stdout dump.
  static String? parseRegQueryAppDataPath(String stdout) {
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (!trimmed.toLowerCase().contains('appdatapath')) {
        continue;
      }
      final match = RegExp(
        r'AppDataPath\s+REG_\w+\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (match == null) {
        continue;
      }
      final value = match.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return WindowsPaths.normalize(value.replaceAll('/', r'\'));
      }
    }
    return null;
  }

  Future<List<DiscoveredApp>> discover() async {
    final roots = await _resolveManifestRoots();
    if (roots.isEmpty) {
      return const [];
    }

    final byKey = <String, DiscoveredApp>{};
    for (final root in roots) {
      final names = await _io.listDirectory(root);
      for (final name in names) {
        if (!name.toLowerCase().endsWith('.item')) {
          continue;
        }
        final filePath = _path.join(root, name);
        String text;
        try {
          text = await _io.readTextFile(filePath);
        } catch (_) {
          continue;
        }
        final parsed = parseItemManifest(text, pathContext: _path);
        if (parsed == null) {
          continue;
        }
        byKey.putIfAbsent(parsed.dedupeKey, () => parsed.toDiscoveredApp());
      }
    }

    final list = byKey.values.toList(growable: false)
      ..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
      );
    return list;
  }

  Future<List<String>> _resolveManifestRoots() async {
    final ordered = <String>[];
    final seen = <String>{};

    void offer(String? raw) {
      if (raw == null) {
        return;
      }
      final normalized = WindowsPaths.normalize(raw.trim());
      if (normalized.isEmpty) {
        return;
      }
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        ordered.add(normalized);
      }
    }

    final appData = await _registryAppDataPath();
    if (appData != null && appData.isNotEmpty) {
      offer(appData);
      offer(_path.join(appData, 'Manifests'));
    }
    for (final candidate in _candidateManifestRoots()) {
      offer(candidate);
    }

    final usable = <String>[];
    final usableSeen = <String>{};
    for (final root in ordered) {
      final key = root.toLowerCase();
      if (!usableSeen.add(key)) {
        continue;
      }
      if (!await _io.directoryExists(root)) {
        continue;
      }
      // Prefer folders that actually list *.item; still accept empty dirs so
      // fixture roots with only manifests elsewhere keep resolving.
      final names = await _io.listDirectory(root);
      final hasItems = names.any((n) => n.toLowerCase().endsWith('.item'));
      if (hasItems || root.toLowerCase().endsWith('manifests')) {
        usable.add(root);
      }
    }
    return usable;
  }
}

/// Parsed Epic `*.item` fields used for discovery.
class EpicItemManifest {
  const EpicItemManifest({
    required this.displayName,
    required this.appName,
    required this.launchTarget,
    this.catalogNamespace,
    this.catalogItemId,
  });

  final String displayName;
  final String appName;
  final LaunchTarget launchTarget;
  final String? catalogNamespace;
  final String? catalogItemId;

  String get dedupeKey {
    final value = launchTarget.value.trim().toLowerCase();
    if (value.isNotEmpty) {
      return value;
    }
    return appName.toLowerCase();
  }

  DiscoveredApp toDiscoveredApp() {
    return DiscoveredApp(
      displayName: displayName,
      kind: TileKind.native,
      target: launchTarget,
    );
  }
}

/// Parses an Epic Games Launcher `*.item` JSON blob.
///
/// Skips incomplete installs. Prefer launcher URI when [AppName] is present;
/// otherwise resolve InstallLocation + LaunchExecutable to a `.exe`.
EpicItemManifest? parseItemManifest(
  String text, {
  p.Context? pathContext,
}) {
  final path = pathContext ?? WindowsPaths.context;
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final map = <String, Object?>{
    for (final entry in decoded.entries) '${entry.key}': entry.value,
  };

  if (_boolField(map, 'bIsIncompleteInstall') == true) {
    return null;
  }

  final appName = _stringField(map, 'AppName')?.trim() ?? '';
  final displayRaw = _stringField(map, 'DisplayName')?.trim();
  final displayName =
      (displayRaw != null && displayRaw.isNotEmpty) ? displayRaw : appName;
  if (displayName.isEmpty) {
    return null;
  }

  final catalogNamespace = _stringField(map, 'CatalogNamespace')?.trim();
  final catalogItemId = _stringField(map, 'CatalogItemId')?.trim();

  final uri = buildEpicLaunchUri(
    appName: appName,
    catalogNamespace: catalogNamespace,
    catalogItemId: catalogItemId,
  );
  if (uri != null) {
    return EpicItemManifest(
      displayName: displayName,
      appName: appName,
      catalogNamespace: catalogNamespace,
      catalogItemId: catalogItemId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: uri,
      ),
    );
  }

  final installLocation = _stringField(map, 'InstallLocation')?.trim() ?? '';
  final launchExecutable = _stringField(map, 'LaunchExecutable')?.trim() ?? '';
  if (installLocation.isEmpty || launchExecutable.isEmpty) {
    return null;
  }
  final exe = WindowsPaths.normalize(
    path.join(
      WindowsPaths.normalize(installLocation.replaceAll('/', r'\')),
      launchExecutable.replaceAll('/', r'\'),
    ),
  );
  if (exe.isEmpty) {
    return null;
  }
  return EpicItemManifest(
    displayName: displayName,
    appName: appName.isEmpty ? displayName : appName,
    catalogNamespace: catalogNamespace,
    catalogItemId: catalogItemId,
    launchTarget: LaunchTarget(
      platform: AppPlatform.windows,
      kind: LaunchTargetKind.windowsExecutable,
      value: exe,
    ),
  );
}

/// Builds `com.epicgames.launcher://apps/…?action=launch&silent=true`.
///
/// Prefers `Namespace%3ACatalogItemId%3AAppName` when all three are present;
/// otherwise `AppName` alone. Returns null when [appName] is empty.
String? buildEpicLaunchUri({
  required String appName,
  String? catalogNamespace,
  String? catalogItemId,
}) {
  final name = appName.trim();
  if (name.isEmpty) {
    return null;
  }
  final ns = catalogNamespace?.trim() ?? '';
  final item = catalogItemId?.trim() ?? '';
  final String appsPath;
  if (ns.isNotEmpty && item.isNotEmpty) {
    // Epic expects colon-separated catalog ids URL-encoded as %3A.
    appsPath = Uri.encodeComponent('$ns:$item:$name');
  } else {
    appsPath = Uri.encodeComponent(name);
  }
  return 'com.epicgames.launcher://apps/$appsPath?action=launch&silent=true';
}

String? _stringField(Map<String, Object?> map, String key) {
  final direct = map[key];
  if (direct is String) {
    return direct;
  }
  for (final entry in map.entries) {
    if (entry.key.toLowerCase() == key.toLowerCase()) {
      final value = entry.value;
      if (value is String) {
        return value;
      }
      if (value != null) {
        return '$value';
      }
    }
  }
  return null;
}

bool? _boolField(Map<String, Object?> map, String key) {
  final direct = map[key];
  if (direct is bool) {
    return direct;
  }
  for (final entry in map.entries) {
    if (entry.key.toLowerCase() == key.toLowerCase()) {
      final value = entry.value;
      if (value is bool) {
        return value;
      }
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true') {
          return true;
        }
        if (lower == 'false') {
          return false;
        }
      }
    }
  }
  return null;
}
