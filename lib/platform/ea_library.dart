import 'dart:io';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:path/path.dart' as p;

/// One installed Origin / EA App title from registry or fixture.
class EaInstallEntry {
  const EaInstallEntry({
    required this.offerId,
    required this.installDir,
    this.displayName,
  });

  final String offerId;
  final String installDir;
  final String? displayName;
}

/// Scans EA App / Origin installs on Windows and emits [DiscoveredApp] rows.
///
/// Roots come from optional `HOMEDECK_EA_ROOT` (Ally / CI fixture), common
/// `%ProgramFiles%\EA Games` / Origin Games candidates, registry
/// `Origin Games\{id}` install dirs, and `%ProgramData%\EA Desktop`
/// InstallData hints. Prefer `origin://launchgame/{offerId}` when an offer /
/// content id is present (also accepts `eaapp://` / `origin2://` launch
/// targets); otherwise resolve a `.exe` under the install folder. Known
/// manifests are `__Installer\installerdata.xml` (contentIDs + game title).
///
/// Does **not** invent games-only filtering — every launchable install /
/// manifest becomes a Library tile (By app → Origin / EA app).
class EaLibraryScanner {
  EaLibraryScanner({
    required WindowsIo io,
    List<String> Function()? candidateRoots,
    Future<List<EaInstallEntry>> Function()? registryInstalls,
    p.Context? pathContext,
  }) : _io = io,
       _candidateRoots = candidateRoots ?? defaultCandidateRoots,
       _registryInstalls = registryInstalls ?? queryInstallsFromRegistry,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _candidateRoots;
  final Future<List<EaInstallEntry>> Function() _registryInstalls;
  final p.Context _path;

  /// Common Games-folder guesses (no hard-coded drive letter).
  ///
  /// Optional `HOMEDECK_EA_ROOT` is tried first: a single game folder with
  /// `__Installer\installerdata.xml`, a Games tree of title subfolders, or a
  /// flat folder of installs.
  static List<String> defaultCandidateRoots() {
    final env = Platform.environment;
    final out = <String>[];
    final path = WindowsPaths.context;
    final forced = env['HOMEDECK_EA_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      final normalized = WindowsPaths.normalize(forced);
      out.add(normalized);
      out.add(path.join(normalized, 'Games'));
      out.add(path.join(normalized, 'EA Games'));
      out.add(path.join(normalized, 'Origin Games'));
    }

    void addUnder(String? base) {
      if (base == null || base.trim().isEmpty) {
        return;
      }
      final root = WindowsPaths.normalize(base);
      out.add(path.join(root, 'EA Games'));
      out.add(path.join(root, 'Origin Games'));
      out.add(path.join(root, 'Electronic Arts'));
      out.add(path.join(root, 'Origin'));
      out.add(path.join(root, 'EA', 'EA Desktop'));
      out.add(path.join(root, 'Electronic Arts', 'EA Desktop'));
    }

    addUnder(env['ProgramFiles(x86)']);
    addUnder(env['ProgramFiles']);
    addUnder(env['PROGRAMFILES(X86)']);
    addUnder(env['PROGRAMFILES']);

    final programData = env['ProgramData']?.trim() ?? env['PROGRAMDATA']?.trim();
    if (programData != null && programData.isNotEmpty) {
      final root = WindowsPaths.normalize(programData);
      out.add(path.join(root, 'EA Desktop', 'InstallData'));
      out.add(path.join(root, 'Origin'));
      out.add(path.join(root, 'Electronic Arts'));
    }

    final systemDrive = env['SystemDrive']?.trim();
    if (systemDrive != null && systemDrive.isNotEmpty) {
      out.add(path.join('$systemDrive\\', 'EA Games'));
      out.add(path.join('$systemDrive\\', 'Origin Games'));
      out.add(
        path.join(
          '$systemDrive\\',
          'Program Files',
          'EA Games',
        ),
      );
      out.add(
        path.join(
          '$systemDrive\\',
          'Program Files (x86)',
          'EA Games',
        ),
      );
    }
    return out;
  }

  /// Reads per-game `Origin Games\{id}` (+ DisplayName / Install Dir) via `reg`.
  static Future<List<EaInstallEntry>> queryInstallsFromRegistry() async {
    if (!Platform.isWindows) {
      return const [];
    }
    final out = <EaInstallEntry>[];
    final seenIds = <String>{};

    for (final gamesKey in const [
      r'HKLM\SOFTWARE\WOW6432Node\Origin Games',
      r'HKLM\SOFTWARE\Origin Games',
      r'HKLM\SOFTWARE\WOW6432Node\EA Games',
      r'HKLM\SOFTWARE\EA Games',
    ]) {
      final subkeys = await _queryRegSubkeys(gamesKey);
      for (final sub in subkeys) {
        final offerId = _offerIdFromGamesSubkey(sub, gamesKey);
        if (offerId == null || offerId.isEmpty || !seenIds.add(offerId)) {
          continue;
        }
        final installDir = await _queryRegSz(
          [
            ['query', sub, '/v', 'Install Dir'],
            ['query', sub, '/v', 'InstallDir'],
            ['query', sub, '/v', 'InstallPath'],
            ['query', sub, '/v', 'path'],
          ],
          valueName: 'Install Dir',
          alternateNames: const ['InstallDir', 'InstallPath', 'path'],
        );
        if (installDir == null || installDir.isEmpty) {
          continue;
        }
        final displayName = await _queryRegSz(
          [
            ['query', sub, '/v', 'DisplayName'],
            ['query', sub, '/v', 'Product Name'],
          ],
          valueName: 'DisplayName',
          alternateNames: const ['Product Name'],
        );
        out.add(
          EaInstallEntry(
            offerId: offerId,
            installDir: installDir,
            displayName: displayName,
          ),
        );
      }
    }
    return out;
  }

  static String? _offerIdFromGamesSubkey(String subkey, String parentKey) {
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
    List<String> alternateNames = const [],
  }) async {
    final names = <String>[valueName, ...alternateNames];
    for (final args in queries) {
      try {
        final result = await Process.run('reg', args, runInShell: false);
        if (result.exitCode != 0) {
          continue;
        }
        final stdout = '${result.stdout}';
        for (final name in names) {
          final parsed = parseRegQuerySz(stdout, name);
          if (parsed != null) {
            return parsed;
          }
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

  /// Lists full subkey paths under a `reg query HKLM\…\Origin Games` dump.
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
      final parsed = await installEntryToManifest(
        entry,
        pathContext: _path,
        io: _io,
      );
      if (parsed == null) {
        continue;
      }
      byKey.putIfAbsent(parsed.dedupeKey, () => parsed.toDiscoveredApp());
    }

    final roots = await _resolveScanRoots();
    for (final root in roots) {
      await _collectInstallerManifest(root, byKey);
      final names = await _io.listDirectory(root);
      for (final name in names) {
        if (_skipDirName(name)) {
          continue;
        }
        final child = _path.join(root, name);
        if (!await _io.directoryExists(child)) {
          continue;
        }
        await _collectInstallerManifest(child, byKey);
        // InstallData\{Game}\base-* style: one more level of children.
        final nested = await _io.listDirectory(child);
        for (final nestedName in nested) {
          if (_skipDirName(nestedName)) {
            continue;
          }
          final nestedChild = _path.join(child, nestedName);
          if (!await _io.directoryExists(nestedChild)) {
            continue;
          }
          await _collectInstallerManifest(nestedChild, byKey);
        }
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

  Future<void> _collectInstallerManifest(
    String folder,
    Map<String, DiscoveredApp> byKey,
  ) async {
    final installerDir = _path.join(folder, '__Installer');
    final altInstallerDir = _path.join(folder, '__installer');
    String? xmlPath;
    for (final dir in [installerDir, altInstallerDir]) {
      final candidate = _path.join(dir, 'installerdata.xml');
      if (await _io.fileExists(candidate)) {
        xmlPath = candidate;
        break;
      }
    }
    if (xmlPath == null) {
      return;
    }
    String text;
    try {
      text = await _io.readTextFile(xmlPath);
    } catch (_) {
      return;
    }
    final parsed = await parseInstallerDataXml(
      text,
      installRoot: folder,
      pathContext: _path,
      io: _io,
    );
    if (parsed == null) {
      return;
    }
    byKey.putIfAbsent(parsed.dedupeKey, () => parsed.toDiscoveredApp());
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

bool _skipDirName(String name) {
  final lower = name.toLowerCase();
  return lower == 'cache' ||
      lower == 'data' ||
      lower == 'logs' ||
      lower == 'crashes' ||
      lower == '__installer' ||
      lower == 'redist' ||
      lower == 'support' ||
      lower.startsWith('.');
}

/// Parsed EA / Origin install / installerdata fields used for discovery.
class EaGameManifest {
  const EaGameManifest({
    required this.displayName,
    required this.offerId,
    required this.launchTarget,
  });

  final String displayName;
  final String offerId;
  final LaunchTarget launchTarget;

  String get dedupeKey {
    final value = launchTarget.value.trim().toLowerCase();
    if (value.isNotEmpty) {
      return value;
    }
    return offerId.toLowerCase();
  }

  DiscoveredApp toDiscoveredApp() {
    return DiscoveredApp(
      displayName: displayName,
      kind: TileKind.native,
      target: launchTarget,
    );
  }
}

/// Builds documented `origin://launchgame/{offerId}` when [offerId] is set.
///
/// EA App also accepts `origin2://game/launch?offerIds=…` and `eaapp://…`;
/// HomeDeck prefers the Origin-style URI that [SourceInference] already maps
/// to [Storefront.ea].
String? buildEaLaunchUri({required String offerId}) {
  final id = offerId.trim();
  if (id.isEmpty) {
    return null;
  }
  return 'origin://launchgame/$id';
}

/// Maps a registry [EaInstallEntry] to a launchable manifest.
Future<EaGameManifest?> installEntryToManifest(
  EaInstallEntry entry, {
  p.Context? pathContext,
  WindowsIo? io,
}) async {
  final path = pathContext ?? WindowsPaths.context;
  final offerId = entry.offerId.trim();
  if (offerId.isEmpty) {
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
      : (fromFolder.isNotEmpty ? fromFolder : 'EA $offerId');

  final uri = buildEaLaunchUri(offerId: offerId);
  if (uri != null) {
    return EaGameManifest(
      displayName: displayName,
      offerId: offerId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: uri,
      ),
    );
  }

  if (io != null && installDir.isNotEmpty) {
    final exe = await findPrimaryExe(installDir, io: io, pathContext: path);
    if (exe != null && exe.isNotEmpty) {
      return EaGameManifest(
        displayName: displayName,
        offerId: offerId,
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

/// Parses `__Installer\installerdata.xml` under [installRoot].
///
/// Prefer `origin://launchgame/{contentID}` when content IDs are present;
/// else resolve optional executable path or the first shallow `.exe`.
Future<EaGameManifest?> parseInstallerDataXml(
  String text, {
  required String installRoot,
  p.Context? pathContext,
  WindowsIo? io,
}) async {
  final path = pathContext ?? WindowsPaths.context;
  final contentIds = contentIdsFromInstallerXml(text);
  final displayRaw = displayNameFromInstallerXml(text)?.trim();
  final root = WindowsPaths.normalize(installRoot.replaceAll('/', r'\'));
  final fromFolder = root.isNotEmpty
      ? path.basename(root.replaceAll(RegExp(r'[\\/]+$'), ''))
      : '';
  final displayName = (displayRaw != null && displayRaw.isNotEmpty)
      ? displayRaw
      : (fromFolder.isNotEmpty
          ? fromFolder
          : (contentIds.isNotEmpty ? contentIds.first : ''));
  if (displayName.isEmpty) {
    return null;
  }

  if (contentIds.isNotEmpty) {
    final offerId = contentIds.first;
    final uri = buildEaLaunchUri(offerId: offerId);
    if (uri != null) {
      return EaGameManifest(
        displayName: displayName,
        offerId: offerId,
        launchTarget: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsUri,
          value: uri,
        ),
      );
    }
  }

  final exeRel = executableFromInstallerXml(text)?.trim();
  if (exeRel != null && exeRel.isNotEmpty) {
    final exe = WindowsPaths.normalize(
      path.isAbsolute(exeRel.replaceAll('/', r'\'))
          ? exeRel.replaceAll('/', r'\')
          : path.join(root, exeRel.replaceAll('/', r'\')),
    );
    if (exe.isNotEmpty) {
      return EaGameManifest(
        displayName: displayName,
        offerId: contentIds.isNotEmpty ? contentIds.first : displayName,
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
      return EaGameManifest(
        displayName: displayName,
        offerId: contentIds.isNotEmpty ? contentIds.first : displayName,
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

/// Pulls every `<contentID>` (any casing) from installerdata XML text.
List<String> contentIdsFromInstallerXml(String text) {
  final out = <String>[];
  final seen = <String>{};
  final pattern = RegExp(
    r'<contentID[^>]*>([^<]+)</contentID>',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(text)) {
    final id = match.group(1)?.trim() ?? '';
    if (id.isEmpty) {
      continue;
    }
    if (seen.add(id.toLowerCase())) {
      out.add(id);
    }
  }
  return out;
}

/// Best-effort game title from `<gameTitle …>…</gameTitle>` / `<title>`.
String? displayNameFromInstallerXml(String text) {
  final enUs = RegExp(
    r'<gameTitle[^>]*locale\s*=\s*"en_US"[^>]*>([^<]+)</gameTitle>',
    caseSensitive: false,
  ).firstMatch(text);
  final fromEn = enUs?.group(1)?.trim();
  if (fromEn != null && fromEn.isNotEmpty) {
    return fromEn;
  }
  final anyTitle = RegExp(
    r'<gameTitle[^>]*>([^<]+)</gameTitle>',
    caseSensitive: false,
  ).firstMatch(text);
  final fromAny = anyTitle?.group(1)?.trim();
  if (fromAny != null && fromAny.isNotEmpty) {
    return fromAny;
  }
  final title = RegExp(
    r'<title[^>]*>([^<]+)</title>',
    caseSensitive: false,
  ).firstMatch(text);
  final fromTitle = title?.group(1)?.trim();
  if (fromTitle != null && fromTitle.isNotEmpty) {
    return fromTitle;
  }
  return null;
}

/// Optional relative / absolute executable hint from installer XML.
String? executableFromInstallerXml(String text) {
  for (final tag in ['filePath', 'executable', 'exePath', 'path']) {
    final match = RegExp(
      '<$tag[^>]*>([^<]+)</$tag>',
      caseSensitive: false,
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value != null &&
        value.isNotEmpty &&
        value.toLowerCase().endsWith('.exe')) {
      return value;
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
  return lower == 'origin.exe' ||
      lower == 'originwebhelperservice.exe' ||
      lower == 'eadesktop.exe' ||
      lower == 'ealauncher.exe' ||
      lower == 'eabackgroundservice.exe' ||
      lower == 'eaanticheat.game.exe' ||
      lower.contains('crash') ||
      lower.contains('unins') ||
      lower.contains('redist') ||
      lower.contains('vcredist') ||
      lower.contains('dotnet') ||
      lower.contains('setup');
}
