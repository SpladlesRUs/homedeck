import 'dart:io';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:path/path.dart' as p;

/// Scans Steam library folders on Windows and emits [DiscoveredApp] rows.
///
/// Roots come from the Valve Steam registry value (when available), common
/// `ProgramFiles` / `ProgramFiles(x86)` candidates, then every `path` listed
/// in `steamapps/libraryfolders.vdf`. Each library's `appmanifest_*.acf`
/// files supply `appid` + `name`; launch targets are `steam://rungameid/{id}`.
class SteamLibraryScanner {
  SteamLibraryScanner({
    required WindowsIo io,
    List<String> Function()? candidateRoots,
    Future<String?> Function()? registrySteamPath,
    p.Context? pathContext,
  }) : _io = io,
       _candidateRoots = candidateRoots ?? defaultCandidateRoots,
       _registrySteamPath = registrySteamPath ?? querySteamPathFromRegistry,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _candidateRoots;
  final Future<String?> Function() _registrySteamPath;
  final p.Context _path;

  /// Common Steam install guesses from environment (no hard-coded drive letter).
  static List<String> defaultCandidateRoots() {
    final env = Platform.environment;
    final out = <String>[];
    final path = WindowsPaths.context;
    void addUnder(String? base) {
      if (base == null || base.trim().isEmpty) {
        return;
      }
      out.add(path.join(base, 'Steam'));
      out.add(path.join(base, 'Steam Library'));
    }

    addUnder(env['ProgramFiles(x86)']);
    addUnder(env['ProgramFiles']);
    addUnder(env['LOCALAPPDATA']);
    return out;
  }

  /// Reads HKCU / HKLM InstallPath or SteamPath via `reg query` on Windows.
  static Future<String?> querySteamPathFromRegistry() async {
    if (!Platform.isWindows) {
      return null;
    }
    const queries = <List<String>>[
      [
        'query',
        r'HKCU\Software\Valve\Steam',
        '/v',
        'SteamPath',
      ],
      [
        'query',
        r'HKLM\SOFTWARE\WOW6432Node\Valve\Steam',
        '/v',
        'InstallPath',
      ],
      [
        'query',
        r'HKLM\SOFTWARE\Valve\Steam',
        '/v',
        'InstallPath',
      ],
    ];
    for (final args in queries) {
      try {
        final result = await Process.run('reg', args, runInShell: false);
        if (result.exitCode != 0) {
          continue;
        }
        final parsed = parseRegQuerySteamPath('${result.stdout}');
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
  static String? parseRegQuerySteamPath(String stdout) {
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final lower = trimmed.toLowerCase();
      if (!lower.contains('steampath') && !lower.contains('installpath')) {
        continue;
      }
      // REG_SZ value is the last whitespace-separated token group after type.
      final match = RegExp(
        r'(SteamPath|InstallPath)\s+REG_\w+\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (match == null) {
        continue;
      }
      final value = match.group(2)?.trim();
      if (value != null && value.isNotEmpty) {
        return WindowsPaths.normalize(value.replaceAll('/', r'\'));
      }
    }
    return null;
  }

  Future<List<DiscoveredApp>> discover() async {
    final roots = await _resolveSteamRoots();
    if (roots.isEmpty) {
      return const [];
    }

    final byAppId = <String, DiscoveredApp>{};
    for (final root in roots) {
      final steamapps = _path.join(root, 'steamapps');
      if (!await _io.directoryExists(steamapps)) {
        continue;
      }
      final names = await _io.listDirectory(steamapps);
      for (final name in names) {
        final lower = name.toLowerCase();
        if (!lower.startsWith('appmanifest_') || !lower.endsWith('.acf')) {
          continue;
        }
        final filePath = _path.join(steamapps, name);
        String text;
        try {
          text = await _io.readTextFile(filePath);
        } catch (_) {
          continue;
        }
        final parsed = parseAppManifest(text);
        if (parsed == null) {
          continue;
        }
        byAppId.putIfAbsent(parsed.appId, () => parsed.toDiscoveredApp());
      }
    }

    final list = byAppId.values.toList(growable: false)
      ..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
    return list;
  }

  Future<List<String>> _resolveSteamRoots() async {
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

    offer(await _registrySteamPath());
    for (final candidate in _candidateRoots()) {
      offer(candidate);
    }

    // Expand via libraryfolders.vdf on every root that looks like Steam.
    final libraries = <String>[];
    for (final root in List<String>.from(ordered)) {
      if (!await _looksLikeSteamRoot(root)) {
        continue;
      }
      libraries.add(root);
      final vdfPath = _path.join(root, 'steamapps', 'libraryfolders.vdf');
      if (!await _io.fileExists(vdfPath)) {
        continue;
      }
      try {
        final text = await _io.readTextFile(vdfPath);
        for (final folder in parseLibraryFolderPaths(text)) {
          offer(folder);
          if (await _looksLikeSteamRoot(folder) ||
              await _io.directoryExists(_path.join(folder, 'steamapps'))) {
            libraries.add(WindowsPaths.normalize(folder));
          }
        }
      } catch (_) {
        // Ignore unreadable VDF; keep other roots.
      }
    }

    // Prefer roots that actually have steamapps/; keep order stable.
    final usable = <String>[];
    final usableSeen = <String>{};
    for (final root in [...libraries, ...ordered]) {
      final normalized = WindowsPaths.normalize(root);
      final key = normalized.toLowerCase();
      if (!usableSeen.add(key)) {
        continue;
      }
      if (await _io.directoryExists(_path.join(normalized, 'steamapps'))) {
        usable.add(normalized);
      }
    }
    return usable;
  }

  Future<bool> _looksLikeSteamRoot(String root) async {
    if (await _io.fileExists(_path.join(root, 'steam.exe'))) {
      return true;
    }
    return _io.directoryExists(_path.join(root, 'steamapps'));
  }
}

/// Parsed Steam `appmanifest_*.acf` fields used for discovery.
class SteamAppManifest {
  const SteamAppManifest({
    required this.appId,
    required this.name,
  });

  final String appId;
  final String name;

  DiscoveredApp toDiscoveredApp() {
    return DiscoveredApp(
      displayName: name,
      kind: TileKind.native,
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: 'steam://rungameid/$appId',
      ),
    );
  }
}

/// Parses `appmanifest_*.acf` for appid + name. Requires Fully Installed bit.
SteamAppManifest? parseAppManifest(String text) {
  final tree = parseVdf(text);
  if (tree == null) {
    return null;
  }
  final appState = _asMap(tree['AppState']) ?? tree;
  final appId = _stringField(appState, 'appid');
  final name = _stringField(appState, 'name');
  if (appId == null || appId.isEmpty || name == null || name.trim().isEmpty) {
    return null;
  }
  // StateFlags bit 2 (value 4) = Fully Installed. Incomplete downloads skip.
  final flagsRaw = _stringField(appState, 'StateFlags');
  if (flagsRaw != null) {
    final flags = int.tryParse(flagsRaw);
    if (flags != null && (flags & 4) == 0) {
      return null;
    }
  }
  return SteamAppManifest(appId: appId, name: name.trim());
}

/// Collects library folder paths from `libraryfolders.vdf` (new + legacy).
List<String> parseLibraryFolderPaths(String text) {
  final tree = parseVdf(text);
  if (tree == null) {
    return const [];
  }
  final root =
      _asMap(tree['libraryfolders']) ??
      _asMap(tree['LibraryFolders']) ??
      tree;
  final paths = <String>[];
  final seen = <String>{};

  void addPath(String? raw) {
    if (raw == null) {
      return;
    }
    final normalized = WindowsPaths.normalize(
      raw.trim().replaceAll('/', r'\'),
    );
    if (normalized.isEmpty) {
      return;
    }
    // Legacy entries are bare paths; skip non-path metadata keys' values
    // that are not absolute Windows paths.
    if (!WindowsPaths.looksLikeVolumePath(normalized) &&
        !WindowsPaths.isAbsolute(normalized)) {
      return;
    }
    if (seen.add(normalized.toLowerCase())) {
      paths.add(normalized);
    }
  }

  for (final entry in root.entries) {
    final value = entry.value;
    if (value is String) {
      // Legacy: "1" "D:\\SteamLibrary"
      addPath(value);
      continue;
    }
    final folder = _asMap(value);
    if (folder == null) {
      continue;
    }
    addPath(_stringField(folder, 'path'));
  }
  return paths;
}

/// Minimal Valve KeyValues (VDF) parser for nested string maps.
Map<String, Object?>? parseVdf(String text) {
  final tokens = _tokenizeVdf(text);
  if (tokens.isEmpty) {
    return null;
  }
  var index = 0;

  Object? parseValue() {
    if (index >= tokens.length) {
      return null;
    }
    final token = tokens[index];
    if (token == '{') {
      index++;
      final map = <String, Object?>{};
      while (index < tokens.length && tokens[index] != '}') {
        final key = tokens[index++];
        if (key == '{' || key == '}') {
          return null;
        }
        final value = parseValue();
        if (value == null && index >= tokens.length) {
          return null;
        }
        map[key] = value;
      }
      if (index < tokens.length && tokens[index] == '}') {
        index++;
      }
      return map;
    }
    index++;
    return token;
  }

  // Top level is usually "AppState" { ... } or "libraryfolders" { ... }.
  if (tokens.length >= 2 && tokens[1] == '{') {
    final key = tokens[index++];
    final value = parseValue();
    if (value is Map<String, Object?>) {
      return {key: value};
    }
    return null;
  }
  final value = parseValue();
  return value is Map<String, Object?> ? value : null;
}

List<String> _tokenizeVdf(String text) {
  final out = <String>[];
  final buf = StringBuffer();
  var i = 0;
  var inQuote = false;

  void flush({bool force = false}) {
    if (force || buf.isNotEmpty) {
      out.add(buf.toString());
      buf.clear();
    }
  }

  while (i < text.length) {
    final ch = text[i];
    if (inQuote) {
      if (ch == '\\' && i + 1 < text.length) {
        buf.write(text[i + 1]);
        i += 2;
        continue;
      }
      if (ch == '"') {
        inQuote = false;
        // Keep empty REG_SZ / VDF values (`"label" ""`) as tokens.
        flush(force: true);
        i++;
        continue;
      }
      buf.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      flush();
      inQuote = true;
      i++;
      continue;
    }
    if (ch == '{' || ch == '}') {
      flush();
      out.add(ch);
      i++;
      continue;
    }
    if (ch == '/' && i + 1 < text.length && text[i + 1] == '/') {
      while (i < text.length && text[i] != '\n') {
        i++;
      }
      continue;
    }
    if (ch.trim().isEmpty) {
      flush();
      i++;
      continue;
    }
    buf.write(ch);
    i++;
  }
  flush();
  return out;
}

Map<String, Object?>? _asMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, v) => MapEntry('$key', v));
  }
  return null;
}

String? _stringField(Map<String, Object?> map, String key) {
  final direct = map[key];
  if (direct is String) {
    return direct;
  }
  for (final entry in map.entries) {
    if (entry.key.toLowerCase() == key.toLowerCase() && entry.value is String) {
      return entry.value as String;
    }
  }
  return null;
}
