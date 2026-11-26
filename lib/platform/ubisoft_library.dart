import 'dart:convert';
import 'dart:io';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:path/path.dart' as p;

/// One installed Ubisoft Connect / Uplay title from registry or fixture.
class UbisoftInstallEntry {
  const UbisoftInstallEntry({
    required this.gameId,
    required this.installDir,
    this.displayName,
  });

  final String gameId;
  final String installDir;
  final String? displayName;
}

/// Scans Ubisoft Connect installs on Windows and emits [DiscoveredApp] rows.
///
/// Roots / installs come from optional `HOMEDECK_UBISOFT_ROOT` (Ally / CI
/// fixture), common `%ProgramFiles%\Ubisoft\…` candidates, and
/// `HKLM\…\Ubisoft\Launcher\Installs\{id}\InstallDir` entries. Prefer
/// `uplay://launch/{gameId}/0` when [gameId] is present; otherwise resolve a
/// `.exe` under the install folder. Fixture folders may ship
/// `ubisoftgame-*.info` JSON (name + gameId) like GOG's `goggame-*.info`.
///
/// Does **not** invent games-only filtering — every launchable install /
/// info file becomes a Library tile (By app → Ubisoft Connect).
class UbisoftLibraryScanner {
  UbisoftLibraryScanner({
    required WindowsIo io,
    List<String> Function()? candidateRoots,
    Future<List<UbisoftInstallEntry>> Function()? registryInstalls,
    p.Context? pathContext,
  }) : _io = io,
       _candidateRoots = candidateRoots ?? defaultCandidateRoots,
       _registryInstalls = registryInstalls ?? queryInstallsFromRegistry,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _candidateRoots;
  final Future<List<UbisoftInstallEntry>> Function() _registryInstalls;
  final p.Context _path;

  /// Common Games-folder guesses (no hard-coded drive letter).
  ///
  /// Optional `HOMEDECK_UBISOFT_ROOT` is tried first: a single game folder
  /// with `ubisoftgame-*.info`, a Games tree of title subfolders, or a flat
  /// folder of info files.
  static List<String> defaultCandidateRoots() {
    final env = Platform.environment;
    final out = <String>[];
    final path = WindowsPaths.context;
    final forced = env['HOMEDECK_UBISOFT_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      final normalized = WindowsPaths.normalize(forced);
      out.add(normalized);
      out.add(path.join(normalized, 'games'));
      out.add(path.join(normalized, 'Games'));
    }

    void addUnder(String? base) {
      if (base == null || base.trim().isEmpty) {
        return;
      }
      final root = WindowsPaths.normalize(base);
      out.add(path.join(root, 'Ubisoft', 'Ubisoft Game Launcher', 'games'));
      out.add(path.join(root, 'Ubisoft Game Launcher', 'games'));
      out.add(path.join(root, 'Ubisoft', 'games'));
      out.add(path.join(root, 'Ubisoft Games'));
    }

    addUnder(env['ProgramFiles(x86)']);
    addUnder(env['ProgramFiles']);
    addUnder(env['PROGRAMFILES(X86)']);
    addUnder(env['PROGRAMFILES']);

    final systemDrive = env['SystemDrive']?.trim();
    if (systemDrive != null && systemDrive.isNotEmpty) {
      out.add(path.join('$systemDrive\\', 'Ubisoft Games'));
      out.add(
        path.join(
          '$systemDrive\\',
          'Program Files (x86)',
          'Ubisoft',
          'Ubisoft Game Launcher',
          'games',
        ),
      );
    }
    return out;
  }

  /// Reads per-game `Installs\{id}\InstallDir` (+ Uninstall DisplayName) via `reg`.
  static Future<List<UbisoftInstallEntry>> queryInstallsFromRegistry() async {
    if (!Platform.isWindows) {
      return const [];
    }
    final out = <UbisoftInstallEntry>[];
    final seenIds = <String>{};

    for (final installsKey in const [
      r'HKLM\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs',
      r'HKLM\SOFTWARE\Ubisoft\Launcher\Installs',
    ]) {
      final subkeys = await _queryRegSubkeys(installsKey);
      for (final sub in subkeys) {
        final gameId = _gameIdFromInstallsSubkey(sub, installsKey);
        if (gameId == null || gameId.isEmpty || !seenIds.add(gameId)) {
          continue;
        }
        final installDir = await _queryRegSz(
          [
            ['query', sub, '/v', 'InstallDir'],
            ['query', sub, '/v', 'installdir'],
          ],
          valueName: 'InstallDir',
        );
        if (installDir == null || installDir.isEmpty) {
          continue;
        }
        final displayName = await _queryDisplayName(gameId);
        out.add(
          UbisoftInstallEntry(
            gameId: gameId,
            installDir: installDir,
            displayName: displayName,
          ),
        );
      }
    }
    return out;
  }

  static Future<String?> _queryDisplayName(String gameId) async {
    final id = gameId.trim();
    if (id.isEmpty) {
      return null;
    }
    return _queryRegSz(
      [
        [
          'query',
          'HKLM\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Uplay Install $id',
          '/v',
          'DisplayName',
        ],
        [
          'query',
          'HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Uplay Install $id',
          '/v',
          'DisplayName',
        ],
      ],
      valueName: 'DisplayName',
    );
  }

  static String? _gameIdFromInstallsSubkey(String subkey, String parentKey) {
    final parent = parentKey.trim().toLowerCase();
    final lower = subkey.trim().toLowerCase();
    if (!lower.startsWith(parent)) {
      return null;
    }
    final rest = subkey.trim().substring(parentKey.trim().length);
    final id = rest.replaceFirst(RegExp(r'^\\+'), '').trim();
    if (id.isEmpty || id.contains(r'\')) {
      return null;
    }
    return id;
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

  /// Lists full subkey paths under a `reg query HKLM\…\Installs` dump.
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
    final byKey = <String, DiscoveredApp>{};

    for (final entry in await _registryInstalls()) {
      final parsed = installEntryToManifest(entry, pathContext: _path);
      if (parsed == null) {
        continue;
      }
      byKey.putIfAbsent(parsed.dedupeKey, () => parsed.toDiscoveredApp());
    }

    final roots = await _resolveScanRoots();
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
      if (!_isUbisoftInfoFile(name)) {
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
      final parsed = await parseUbisoftInfo(
        text,
        installRoot: folder,
        gameIdHint: gameIdHint,
        pathContext: _path,
        io: _io,
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

bool _isUbisoftInfoFile(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('ubisoftgame-') && lower.endsWith('.info');
}

bool _skipDirName(String name) {
  final lower = name.toLowerCase();
  return lower == 'cache' ||
      lower == 'data' ||
      lower == 'logs' ||
      lower == 'crashes' ||
      lower.startsWith('.');
}

/// Pulls `{id}` from `ubisoftgame-{id}.info`.
String? gameIdFromInfoFileName(String name) {
  final match = RegExp(
    r'^ubisoftgame-([0-9A-Za-z]+)\.info$',
    caseSensitive: false,
  ).firstMatch(name.trim());
  return match?.group(1);
}

/// Parsed Ubisoft install / info fields used for discovery.
class UbisoftGameManifest {
  const UbisoftGameManifest({
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

/// Builds documented `uplay://launch/{gameId}/0` when [gameId] is set.
///
/// `ubisoftconnect://` is recognized by [SourceInference] for store
/// grouping; launch URIs use the widely documented `uplay://` scheme.
String? buildUbisoftLaunchUri({required String gameId}) {
  final id = gameId.trim();
  if (id.isEmpty) {
    return null;
  }
  return 'uplay://launch/$id/0';
}

/// Maps a registry [UbisoftInstallEntry] to a launchable manifest.
UbisoftGameManifest? installEntryToManifest(
  UbisoftInstallEntry entry, {
  p.Context? pathContext,
}) {
  final path = pathContext ?? WindowsPaths.context;
  final gameId = entry.gameId.trim();
  if (gameId.isEmpty) {
    return null;
  }
  final installDir = WindowsPaths.normalize(
    entry.installDir.trim().replaceAll('/', r'\'),
  );
  final fromUninstall = entry.displayName?.trim();
  final fromFolder = installDir.isNotEmpty
      ? path.basename(installDir.replaceAll(RegExp(r'[\\/]+$'), ''))
      : '';
  final displayName = (fromUninstall != null && fromUninstall.isNotEmpty)
      ? fromUninstall
      : (fromFolder.isNotEmpty ? fromFolder : 'Ubisoft $gameId');

  final uri = buildUbisoftLaunchUri(gameId: gameId);
  if (uri == null) {
    return null;
  }
  return UbisoftGameManifest(
    displayName: displayName,
    gameId: gameId,
    launchTarget: LaunchTarget(
      platform: AppPlatform.windows,
      kind: LaunchTargetKind.windowsUri,
      value: uri,
    ),
  );
}

/// Parses a fixture `ubisoftgame-*.info` JSON blob under [installRoot].
///
/// Prefer `uplay://launch/{gameId}/0` when an id is present; else resolve
/// optional `exe` / `executable` / `path`, or the first shallow `.exe`.
Future<UbisoftGameManifest?> parseUbisoftInfo(
  String text, {
  required String installRoot,
  String? gameIdHint,
  p.Context? pathContext,
  WindowsIo? io,
}) async {
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

  final uri = buildUbisoftLaunchUri(gameId: gameId);
  if (uri != null) {
    return UbisoftGameManifest(
      displayName: displayName,
      gameId: gameId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: uri,
      ),
    );
  }

  final root = WindowsPaths.normalize(installRoot.replaceAll('/', r'\'));
  final exeRel = _stringField(map, 'exe')?.trim() ??
      _stringField(map, 'executable')?.trim() ??
      _stringField(map, 'path')?.trim();
  if (exeRel != null && exeRel.isNotEmpty) {
    final exe = WindowsPaths.normalize(
      path.join(root, exeRel.replaceAll('/', r'\')),
    );
    if (exe.isNotEmpty) {
      return UbisoftGameManifest(
        displayName: displayName,
        gameId: gameId.isEmpty ? displayName : gameId,
        launchTarget: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsExecutable,
          value: exe,
        ),
      );
    }
  }

  if (io != null) {
    final exe = await findPrimaryExe(root, io: io, pathContext: path);
    if (exe != null && exe.isNotEmpty) {
      return UbisoftGameManifest(
        displayName: displayName,
        gameId: gameId.isEmpty ? displayName : gameId,
        launchTarget: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsExecutable,
          value: exe,
        ),
      );
    }
  }
  return null;
}

/// Picks a shallow launchable `.exe` under [installRoot], skipping launcher /
/// redistributable names.
Future<String?> findPrimaryExe(
  String installRoot, {
  required WindowsIo io,
  p.Context? pathContext,
}) async {
  final path = pathContext ?? WindowsPaths.context;
  final root = WindowsPaths.normalize(installRoot.replaceAll('/', r'\'));
  if (root.isEmpty || !await io.directoryExists(root)) {
    return null;
  }
  final names = await io.listDirectory(root);
  String? first;
  for (final name in names) {
    if (!name.toLowerCase().endsWith('.exe')) {
      continue;
    }
    if (_skipExeName(name)) {
      continue;
    }
    final full = WindowsPaths.normalize(path.join(root, name));
    first ??= full;
    final base = path.basenameWithoutExtension(root).toLowerCase();
    if (base.isNotEmpty && name.toLowerCase().contains(base)) {
      return full;
    }
  }
  return first;
}

bool _skipExeName(String name) {
  final lower = name.toLowerCase();
  return lower == 'upc.exe' ||
      lower == 'ubisoftconnect.exe' ||
      lower == 'uplay.exe' ||
      lower == 'uplayservice.exe' ||
      lower.contains('crash') ||
      lower.contains('unins') ||
      lower.contains('redist') ||
      lower.contains('vcredist') ||
      lower.contains('dotnet');
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
