import 'dart:convert';
import 'dart:io';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:path/path.dart' as p;

/// Scans GOG Galaxy installs on Windows and emits [DiscoveredApp] rows.
///
/// Roots come from optional `HOMEDECK_GOG_ROOT` (Ally / CI fixture), the
/// Galaxy client `paths\client` registry value (+ `Games`), common
/// `%ProgramFiles%\GOG Galaxy\Games` / `GOG Games` candidates, and
/// `HKLM\…\GOG.com\Games\{id}\path` install entries. Each `goggame-*.info`
/// JSON supplies display name + launch target. Prefer
/// `goggalaxy://openGameView/{gameId}` when [gameId] is present; otherwise
/// resolve the primary `playTasks` `.exe` under the install folder.
///
/// Does **not** invent games-only filtering — every launchable info file
/// becomes a Library tile (By app → GOG).
class GogLibraryScanner {
  GogLibraryScanner({
    required WindowsIo io,
    List<String> Function()? candidateRoots,
    Future<List<String>> Function()? registryInstallRoots,
    p.Context? pathContext,
  }) : _io = io,
       _candidateRoots = candidateRoots ?? defaultCandidateRoots,
       _registryInstallRoots =
           registryInstallRoots ?? queryInstallRootsFromRegistry,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _candidateRoots;
  final Future<List<String>> Function() _registryInstallRoots;
  final p.Context _path;

  /// Common Games-folder guesses (no hard-coded drive letter).
  ///
  /// Optional `HOMEDECK_GOG_ROOT` is tried first: a single game folder with
  /// `goggame-*.info`, a Games tree of title subfolders, or a flat folder of
  /// info files.
  static List<String> defaultCandidateRoots() {
    final env = Platform.environment;
    final out = <String>[];
    final path = WindowsPaths.context;
    final forced = env['HOMEDECK_GOG_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      final normalized = WindowsPaths.normalize(forced);
      out.add(normalized);
      out.add(path.join(normalized, 'Games'));
    }

    void addGamesUnder(String? base) {
      if (base == null || base.trim().isEmpty) {
        return;
      }
      final root = WindowsPaths.normalize(base);
      out.add(path.join(root, 'GOG Galaxy', 'Games'));
      out.add(path.join(root, 'GOG Games'));
    }

    addGamesUnder(env['ProgramFiles(x86)']);
    addGamesUnder(env['ProgramFiles']);
    addGamesUnder(env['PROGRAMFILES(X86)']);
    addGamesUnder(env['PROGRAMFILES']);

    final systemDrive = env['SystemDrive']?.trim();
    if (systemDrive != null && systemDrive.isNotEmpty) {
      out.add(path.join('$systemDrive\\', 'GOG Games'));
      out.add(path.join('$systemDrive\\', 'GOG Galaxy', 'Games'));
    }
    return out;
  }

  /// Reads Galaxy client path + per-game `GOG.com\Games\{id}\path` via `reg`.
  static Future<List<String>> queryInstallRootsFromRegistry() async {
    if (!Platform.isWindows) {
      return const [];
    }
    final out = <String>[];
    final path = WindowsPaths.context;

    final client = await _queryRegSz(
      const [
        [
          'query',
          r'HKLM\SOFTWARE\WOW6432Node\GOG.com\GalaxyClient\paths',
          '/v',
          'client',
        ],
        [
          'query',
          r'HKLM\SOFTWARE\GOG.com\GalaxyClient\paths',
          '/v',
          'client',
        ],
      ],
      valueName: 'client',
    );
    if (client != null && client.isNotEmpty) {
      out.add(client);
      out.add(path.join(client, 'Games'));
    }

    for (final gamesKey in const [
      r'HKLM\SOFTWARE\WOW6432Node\GOG.com\Games',
      r'HKLM\SOFTWARE\GOG.com\Games',
    ]) {
      final subkeys = await _queryRegSubkeys(gamesKey);
      for (final sub in subkeys) {
        final install = await _queryRegSz(
          [
            ['query', sub, '/v', 'path'],
            ['query', sub, '/v', 'PATH'],
          ],
          valueName: 'path',
        );
        if (install != null && install.isNotEmpty) {
          out.add(install);
        }
      }
    }
    return out;
  }

  static Future<String?> _queryRegSz(
    List<List<String>> queries, {
    required String valueName,
  }) async {
    for (final args in queries) {
      try {
        final result = await Process.run('reg', args, runInShell: false);
        if (result.exitCode != 0) {
          continue;
        }
        final parsed = parseRegQuerySz('${result.stdout}', valueName);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // Missing reg.exe or access denied — try next key.
      }
    }
    return null;
  }

  static Future<List<String>> _queryRegSubkeys(String key) async {
    try {
      final result = await Process.run(
        'reg',
        ['query', key],
        runInShell: false,
      );
      if (result.exitCode != 0) {
        return const [];
      }
      return parseRegQuerySubkeys('${result.stdout}', parentKey: key);
    } catch (_) {
      return const [];
    }
  }

  /// Pulls a REG_SZ data column from a `reg query` stdout dump.
  static String? parseRegQuerySz(String stdout, String valueName) {
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (!trimmed.toLowerCase().contains(valueName.toLowerCase())) {
        continue;
      }
      final match = RegExp(
        '${RegExp.escape(valueName)}\\s+REG_\\w+\\s+(.+)\$',
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

  /// Lists full subkey paths under a `reg query HKLM\…\Games` dump.
  static List<String> parseRegQuerySubkeys(
    String stdout, {
    required String parentKey,
  }) {
    final parent = parentKey.trim().toLowerCase();
    final out = <String>[];
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final lower = trimmed.toLowerCase();
      if (lower == parent) {
        continue;
      }
      if (lower.startsWith(parent) && trimmed.contains(r'\')) {
        out.add(trimmed);
      }
    }
    return out;
  }

  Future<List<DiscoveredApp>> discover() async {
    final roots = await _resolveScanRoots();
    if (roots.isEmpty) {
      return const [];
    }

    final byKey = <String, DiscoveredApp>{};
    for (final root in roots) {
      await _collectInfoFiles(root, byKey);
      final names = await _io.listDirectory(root);
      for (final name in names) {
        if (_skipDirName(name)) {
          continue;
        }
        final child = _path.join(root, name);
        if (!await _io.directoryExists(child)) {
          continue;
        }
        await _collectInfoFiles(child, byKey);
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

  Future<void> _collectInfoFiles(
    String folder,
    Map<String, DiscoveredApp> byKey,
  ) async {
    final names = await _io.listDirectory(folder);
    for (final name in names) {
      if (!_isGogInfoFile(name)) {
        continue;
      }
      final filePath = _path.join(folder, name);
      String text;
      try {
        text = await _io.readTextFile(filePath);
      } catch (_) {
        continue;
      }
      final gameIdHint = gameIdFromInfoFileName(name);
      final parsed = parseGogInfo(
        text,
        installRoot: folder,
        gameIdHint: gameIdHint,
        pathContext: _path,
      );
      if (parsed == null) {
        continue;
      }
      byKey.putIfAbsent(parsed.dedupeKey, () => parsed.toDiscoveredApp());
    }
  }

  Future<List<String>> _resolveScanRoots() async {
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

    for (final candidate in _candidateRoots()) {
      offer(candidate);
    }
    for (final registered in await _registryInstallRoots()) {
      offer(registered);
    }

    final usable = <String>[];
    for (final root in ordered) {
      if (!await _io.directoryExists(root)) {
        continue;
      }
      usable.add(root);
    }
    return usable;
  }
}

bool _isGogInfoFile(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('goggame-') && lower.endsWith('.info');
}

bool _skipDirName(String name) {
  final lower = name.toLowerCase();
  return lower == '_commonredist' ||
      lower == 'saves' ||
      lower == 'support' ||
      lower.startsWith('.');
}

/// Pulls `{id}` from `goggame-{id}.info`.
String? gameIdFromInfoFileName(String name) {
  final match = RegExp(
    r'^goggame-(\d+)\.info$',
    caseSensitive: false,
  ).firstMatch(name.trim());
  return match?.group(1);
}

/// Parsed GOG `goggame-*.info` fields used for discovery.
class GogInfoManifest {
  const GogInfoManifest({
    required this.displayName,
    required this.gameId,
    required this.launchTarget,
  });

  final String displayName;
  final String gameId;
  final LaunchTarget launchTarget;

  String get dedupeKey {
    final value = launchTarget.value.trim().toLowerCase();
    if (value.isNotEmpty) {
      return value;
    }
    return gameId.toLowerCase();
  }

  DiscoveredApp toDiscoveredApp() {
    return DiscoveredApp(
      displayName: displayName,
      kind: TileKind.native,
      target: launchTarget,
    );
  }
}

/// Parses a GOG `goggame-*.info` JSON blob under [installRoot].
///
/// Prefer `goggalaxy://openGameView/{gameId}` when an id is present; else
/// resolve the primary playTask path to a `.exe`.
GogInfoManifest? parseGogInfo(
  String text, {
  required String installRoot,
  String? gameIdHint,
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

  final gameId = (_stringField(map, 'gameId')?.trim().isNotEmpty == true
          ? _stringField(map, 'gameId')!.trim()
          : (gameIdHint?.trim() ?? ''));
  final displayRaw = _stringField(map, 'name')?.trim();
  final displayName =
      (displayRaw != null && displayRaw.isNotEmpty) ? displayRaw : gameId;
  if (displayName.isEmpty) {
    return null;
  }

  final uri = buildGogLaunchUri(gameId: gameId);
  if (uri != null) {
    return GogInfoManifest(
      displayName: displayName,
      gameId: gameId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: uri,
      ),
    );
  }

  final exeRel = _primaryPlayTaskPath(map);
  if (exeRel == null || exeRel.isEmpty) {
    return null;
  }
  final root = WindowsPaths.normalize(installRoot.replaceAll('/', r'\'));
  final exe = WindowsPaths.normalize(
    path.join(root, exeRel.replaceAll('/', r'\')),
  );
  if (exe.isEmpty) {
    return null;
  }
  return GogInfoManifest(
    displayName: displayName,
    gameId: gameId.isEmpty ? displayName : gameId,
    launchTarget: LaunchTarget(
      platform: AppPlatform.windows,
      kind: LaunchTargetKind.windowsExecutable,
      value: exe,
    ),
  );
}

/// Builds documented `goggalaxy://openGameView/{gameId}` when [gameId] is set.
String? buildGogLaunchUri({required String gameId}) {
  final id = gameId.trim();
  if (id.isEmpty) {
    return null;
  }
  return 'goggalaxy://openGameView/$id';
}

String? _primaryPlayTaskPath(Map<String, Object?> map) {
  final raw = map['playTasks'] ?? map['PlayTasks'];
  if (raw is! List) {
    return null;
  }
  Map<String, Object?>? primary;
  Map<String, Object?>? firstFile;
  for (final entry in raw) {
    if (entry is! Map) {
      continue;
    }
    final task = <String, Object?>{
      for (final e in entry.entries) '${e.key}': e.value,
    };
    final taskPath = _stringField(task, 'path')?.trim() ?? '';
    if (taskPath.isEmpty) {
      continue;
    }
    final type = _stringField(task, 'type')?.trim().toLowerCase() ?? '';
    final looksFile = type.isEmpty ||
        type == 'filetask' ||
        taskPath.toLowerCase().endsWith('.exe');
    if (!looksFile) {
      continue;
    }
    firstFile ??= task;
    if (_boolField(task, 'isPrimary') == true) {
      primary = task;
      break;
    }
  }
  final chosen = primary ?? firstFile;
  if (chosen == null) {
    return null;
  }
  return _stringField(chosen, 'path')?.trim();
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
