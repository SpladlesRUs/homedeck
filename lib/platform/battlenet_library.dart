import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:path/path.dart' as p;

/// One installed Battle.net title from Agent `product.db`, registry, or fixture.
class BattlenetInstallEntry {
  const BattlenetInstallEntry({
    required this.uid,
    required this.productCode,
    required this.installDir,
    this.displayName,
  });

  /// Agent internal id (e.g. `wow`, `diablo3`, `prometheus`).
  final String uid;

  /// Launch / URI product code (e.g. `WoW`, `D3`, `Pro`) — case-sensitive.
  final String productCode;

  final String installDir;
  final String? displayName;
}

/// Scans Battle.net installs on Windows and emits [DiscoveredApp] rows.
///
/// Roots / installs come from optional `HOMEDECK_BATTLENET_ROOT` (Ally / CI
/// fixture), `%ProgramData%\Battle.net\Agent\product.db`, common Games-folder
/// candidates, and Uninstall entries whose string contains
/// `Battle.net … --uid=…`. Prefer `battlenet://{productCode}/` when a product
/// code is present; otherwise resolve a `.exe` under the install folder.
/// Fixture folders may ship `battlenetgame-*.info` JSON (name + productCode /
/// uid) or a `product.db` / `Agent\product.db` blob.
///
/// Does **not** invent games-only filtering — every launchable product /
/// info file becomes a Library tile (By app → Battle.net). Agent / client
/// component uids (`battle.net`, `agent`, …) are skipped as non-launchable.
class BattlenetLibraryScanner {
  BattlenetLibraryScanner({
    required WindowsIo io,
    List<String> Function()? candidateRoots,
    Future<List<BattlenetInstallEntry>> Function()? registryInstalls,
    Future<List<BattlenetInstallEntry>> Function()? productDbInstalls,
    Future<List<int>> Function(String path)? readBinary,
    p.Context? pathContext,
  }) : _io = io,
       _candidateRoots = candidateRoots ?? defaultCandidateRoots,
       _registryInstalls = registryInstalls ?? queryInstallsFromRegistry,
       _productDbInstalls = productDbInstalls,
       _readBinary = readBinary ?? _defaultReadBinary,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _candidateRoots;
  final Future<List<BattlenetInstallEntry>> Function() _registryInstalls;
  final Future<List<BattlenetInstallEntry>> Function()? _productDbInstalls;
  final Future<List<int>> Function(String path) _readBinary;
  final p.Context _path;

  static Future<List<int>> _defaultReadBinary(String path) async {
    return File(path).readAsBytes();
  }

  /// Common Agent / Games-folder guesses (no hard-coded drive letter).
  ///
  /// Optional `HOMEDECK_BATTLENET_ROOT` is tried first: a fixture tree with
  /// `product.db` / `Agent\product.db`, `battlenetgame-*.info`, or title
  /// subfolders.
  static List<String> defaultCandidateRoots() {
    final env = Platform.environment;
    final out = <String>[];
    final path = WindowsPaths.context;
    final forced = env['HOMEDECK_BATTLENET_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      final normalized = WindowsPaths.normalize(forced);
      out.add(normalized);
      out.add(path.join(normalized, 'Games'));
      out.add(path.join(normalized, 'games'));
      out.add(path.join(normalized, 'Agent'));
      out.add(path.join(normalized, 'Battle.net'));
      out.add(path.join(normalized, 'Battle.net', 'Agent'));
    }

    void addUnder(String? base) {
      if (base == null || base.trim().isEmpty) {
        return;
      }
      final root = WindowsPaths.normalize(base);
      out.add(path.join(root, 'Battle.net'));
      out.add(path.join(root, 'Battle.net', 'Games'));
      out.add(path.join(root, 'Blizzard Entertainment'));
      out.add(path.join(root, 'Blizzard'));
    }

    addUnder(env['ProgramFiles(x86)']);
    addUnder(env['ProgramFiles']);
    addUnder(env['PROGRAMFILES(X86)']);
    addUnder(env['PROGRAMFILES']);

    final programData = env['ProgramData']?.trim() ?? env['PROGRAMDATA']?.trim();
    if (programData != null && programData.isNotEmpty) {
      final root = WindowsPaths.normalize(programData);
      out.add(path.join(root, 'Battle.net'));
      out.add(path.join(root, 'Battle.net', 'Agent'));
    }

    final systemDrive = env['SystemDrive']?.trim();
    if (systemDrive != null && systemDrive.isNotEmpty) {
      out.add(path.join('$systemDrive\\', 'ProgramData', 'Battle.net', 'Agent'));
      out.add(
        path.join(
          '$systemDrive\\',
          'Program Files (x86)',
          'Battle.net',
        ),
      );
    }
    return out;
  }

  /// Default `product.db` locations (ProgramData Agent + fixture env).
  static List<String> defaultProductDbPaths() {
    final env = Platform.environment;
    final path = WindowsPaths.context;
    final out = <String>[];
    final forced = env['HOMEDECK_BATTLENET_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      final normalized = WindowsPaths.normalize(forced);
      out.add(path.join(normalized, 'product.db'));
      out.add(path.join(normalized, 'Agent', 'product.db'));
      out.add(path.join(normalized, 'Battle.net', 'Agent', 'product.db'));
    }
    final programData = env['ProgramData']?.trim() ?? env['PROGRAMDATA']?.trim();
    if (programData != null && programData.isNotEmpty) {
      out.add(
        path.join(
          WindowsPaths.normalize(programData),
          'Battle.net',
          'Agent',
          'product.db',
        ),
      );
    }
    final systemDrive = env['SystemDrive']?.trim();
    if (systemDrive != null && systemDrive.isNotEmpty) {
      out.add(
        path.join(
          '$systemDrive\\',
          'ProgramData',
          'Battle.net',
          'Agent',
          'product.db',
        ),
      );
    }
    return out;
  }

  /// Reads Uninstall entries with `Battle.net … --uid=` via `reg`.
  static Future<List<BattlenetInstallEntry>> queryInstallsFromRegistry() async {
    if (!Platform.isWindows) {
      return const [];
    }
    final out = <BattlenetInstallEntry>[];
    final seen = <String>{};

    for (final uninstallRoot in const [
      r'HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
      r'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    ]) {
      final subkeys = await _queryRegSubkeys(uninstallRoot);
      for (final sub in subkeys) {
        final uninstall = await _queryRegSz(
          [
            ['query', sub, '/v', 'UninstallString'],
          ],
          valueName: 'UninstallString',
        );
        if (uninstall == null || uninstall.isEmpty) {
          continue;
        }
        final uid = uidFromUninstallString(uninstall);
        if (uid == null || uid.isEmpty || isAgentComponent(uid)) {
          continue;
        }
        final installDir = await _queryRegSz(
          [
            ['query', sub, '/v', 'InstallLocation'],
            ['query', sub, '/v', 'InstallDir'],
          ],
          valueName: 'InstallLocation',
          alternateNames: const ['InstallDir'],
        );
        if (installDir == null || installDir.isEmpty) {
          continue;
        }
        final displayName = await _queryRegSz(
          [
            ['query', sub, '/v', 'DisplayName'],
          ],
          valueName: 'DisplayName',
        );
        final productCode = productCodeForUid(uid) ?? uid;
        final key = productCode.toLowerCase();
        if (!seen.add(key)) {
          continue;
        }
        out.add(
          BattlenetInstallEntry(
            uid: uid,
            productCode: productCode,
            installDir: installDir,
            displayName: displayName,
          ),
        );
      }
    }
    return out;
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

  /// Lists full subkey paths under a `reg query HKLM\…\Uninstall` dump.
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

    Future<void> offerEntry(BattlenetInstallEntry entry) async {
      final parsed = await installEntryToManifest(
        entry,
        pathContext: _path,
        io: _io,
      );
      if (parsed == null) {
        return;
      }
      byKey.putIfAbsent(parsed.dedupeKey, () => parsed.toDiscoveredApp());
    }

    for (final entry in await _loadProductDbInstalls()) {
      await offerEntry(entry);
    }
    for (final entry in await _registryInstalls()) {
      await offerEntry(entry);
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

  Future<List<BattlenetInstallEntry>> _loadProductDbInstalls() async {
    final injected = _productDbInstalls;
    if (injected != null) {
      return injected();
    }
    final out = <BattlenetInstallEntry>[];
    final seen = <String>{};
    for (final dbPath in defaultProductDbPaths()) {
      if (!await _io.fileExists(dbPath)) {
        continue;
      }
      List<int> bytes;
      try {
        bytes = await _readBinary(dbPath);
      } catch (_) {
        continue;
      }
      for (final entry in parseProductDb(Uint8List.fromList(bytes))) {
        final key = entry.productCode.toLowerCase();
        if (!seen.add(key)) {
          continue;
        }
        out.add(entry);
      }
    }
    return out;
  }

  Future<void> _collectInfoFiles(
    String folder,
    Map<String, DiscoveredApp> byKey,
  ) async {
    final names = await _io.listDirectory(folder);
    for (final name in names) {
      if (!_isBattlenetInfoFile(name)) {
        continue;
      }
      final filePath = _path.join(folder, name);
      String text;
      try {
        text = await _io.readTextFile(filePath);
      } catch (_) {
        continue;
      }
      final codeHint = productCodeFromInfoFileName(name);
      final parsed = await parseBattlenetInfo(
        text,
        installRoot: folder,
        productCodeHint: codeHint,
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

bool _isBattlenetInfoFile(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('battlenetgame-') && lower.endsWith('.info');
}

bool _skipDirName(String name) {
  final lower = name.toLowerCase();
  return lower == 'cache' ||
      lower == 'data' ||
      lower == 'logs' ||
      lower == 'crashes' ||
      lower == 'agent' ||
      lower.startsWith('.');
}

/// Pulls `{code}` from `battlenetgame-{code}.info`.
String? productCodeFromInfoFileName(String name) {
  final match = RegExp(
    r'^battlenetgame-([0-9A-Za-z]+)\.info$',
    caseSensitive: false,
  ).firstMatch(name.trim());
  return match?.group(1);
}

/// `--uid=` from a Battle.net UninstallString.
String? uidFromUninstallString(String uninstall) {
  final match = RegExp(
    r'Battle\.net.*--uid=([^\s"]+)',
    caseSensitive: false,
  ).firstMatch(uninstall);
  return match?.group(1)?.trim();
}

/// Agent / client component uids that are not launchable game tiles.
bool isAgentComponent(String uid) {
  final lower = uid.trim().toLowerCase();
  if (lower.isEmpty) {
    return true;
  }
  return lower == 'battle.net' ||
      lower == 'agent' ||
      lower == 'bna' ||
      lower == 'bnt' ||
      lower == 'bsap' ||
      lower == 's2_locator' ||
      lower.startsWith('agent_') ||
      lower.endsWith('_installer');
}

/// Well-known uid → product code (case-sensitive for `battlenet://` launch).
String? productCodeForUid(String uid) {
  final lower = uid.trim().toLowerCase();
  const map = <String, String>{
    'wow': 'WoW',
    'wow_beta': 'WoW',
    'wow_classic': 'WoW',
    'diablo3': 'D3',
    'd3': 'D3',
    'd3cn': 'D3',
    's2': 'S2',
    's1': 'S1',
    'hs_beta': 'WTCG',
    'hearthstone': 'WTCG',
    'heroes': 'Hero',
    'prometheus': 'Pro',
    'viper': 'VIPR',
    'odin': 'ODIN',
    'w3': 'W3',
    'lazarus': 'LAZR',
    'zeus': 'ZEUS',
    'wlby': 'WLBY',
    'osi': 'OSI',
    'rtro': 'RTRO',
    'fore': 'FORE',
    'anbs': 'ANBS',
    'auks': 'AUKS',
    'fen': 'Fen',
    'd1': 'D1',
    'w1r': 'W1R',
    'w2r': 'W2R',
    'w1': 'W1',
    'w2': 'W2',
    'gryphon': 'GRY',
    'aris': 'ARIS',
    'scorpio': 'SCOR',
    'arkansas': 'ARK',
    'libra': 'LBRA',
    'pinta': 'PNTA',
    'aqua': 'AQUA',
  };
  return map[lower];
}

/// Friendly title for a product code / uid when DisplayName is missing.
String? displayNameForProduct({
  required String productCode,
  required String uid,
}) {
  const byCode = <String, String>{
    'WoW': 'World of Warcraft',
    'D3': 'Diablo III',
    'S2': 'StarCraft II',
    'S1': 'StarCraft',
    'WTCG': 'Hearthstone',
    'Hero': 'Heroes of the Storm',
    'Pro': 'Overwatch 2',
    'VIPR': 'Call of Duty: Black Ops 4',
    'ODIN': 'Call of Duty: Modern Warfare',
    'W3': 'Warcraft III: Reforged',
    'LAZR': 'Call of Duty: Modern Warfare 2 Campaign Remastered',
    'ZEUS': 'Call of Duty: Black Ops Cold War',
    'WLBY': 'Crash Bandicoot 4',
    'OSI': 'Diablo II: Resurrected',
    'RTRO': 'Blizzard Arcade Collection',
    'FORE': 'Call of Duty: Vanguard',
    'ANBS': 'Diablo Immortal',
    'AUKS': 'Call of Duty: Modern Warfare II',
    'Fen': 'Diablo IV',
    'D1': 'Diablo',
    'W1R': 'Warcraft: Remastered',
    'W2R': 'Warcraft II: Remastered',
    'W1': 'Warcraft: Orcs & Humans',
    'W2': 'Warcraft II: Battle.net Edition',
    'GRY': 'Warcraft Rumble',
    'ARIS': "Doom: The Dark Ages",
    'SCOR': 'Sea of Thieves',
    'ARK': 'The Outer Worlds 2',
    'LBRA': "Tony Hawk's Pro Skater 3 + 4",
    'PNTA': 'Call of Duty: Modern Warfare III',
    'AQUA': 'Avowed',
  };
  final direct = byCode[productCode];
  if (direct != null) {
    return direct;
  }
  for (final entry in byCode.entries) {
    if (entry.key.toLowerCase() == productCode.toLowerCase()) {
      return entry.value;
    }
  }
  final fromUid = productCodeForUid(uid);
  if (fromUid != null && byCode.containsKey(fromUid)) {
    return byCode[fromUid];
  }
  return null;
}

/// Parsed Battle.net install / info fields used for discovery.
class BattlenetGameManifest {
  const BattlenetGameManifest({
    required this.displayName,
    required this.productCode,
    required this.launchTarget,
  });

  final String displayName;
  final String productCode;
  final LaunchTarget launchTarget;

  String get dedupeKey {
    final value = launchTarget.value.trim().toLowerCase();
    if (value.isNotEmpty) {
      return value;
    }
    return productCode.toLowerCase();
  }

  DiscoveredApp toDiscoveredApp() {
    return DiscoveredApp(
      displayName: displayName,
      kind: TileKind.native,
      target: launchTarget,
    );
  }
}

/// Builds documented `battlenet://{productCode}/` when [productCode] is set.
String? buildBattlenetLaunchUri({required String productCode}) {
  final code = productCode.trim();
  if (code.isEmpty) {
    return null;
  }
  return 'battlenet://$code/';
}

/// Maps a [BattlenetInstallEntry] to a launchable manifest.
Future<BattlenetGameManifest?> installEntryToManifest(
  BattlenetInstallEntry entry, {
  p.Context? pathContext,
  WindowsIo? io,
}) async {
  final path = pathContext ?? WindowsPaths.context;
  final uid = entry.uid.trim();
  if (isAgentComponent(uid) && entry.productCode.trim().isEmpty) {
    return null;
  }
  var productCode = entry.productCode.trim();
  if (productCode.isEmpty) {
    productCode = productCodeForUid(uid) ?? '';
  }
  if (productCode.isEmpty) {
    return null;
  }
  if (isAgentComponent(uid) &&
      productCode.toLowerCase() == 'battle.net') {
    return null;
  }

  final installDir = WindowsPaths.normalize(
    entry.installDir.trim().replaceAll('/', r'\'),
  );
  final fromUninstall = entry.displayName?.trim();
  final known = displayNameForProduct(productCode: productCode, uid: uid);
  final fromFolder = installDir.isNotEmpty
      ? path.basename(installDir.replaceAll(RegExp(r'[\\/]+$'), ''))
      : '';
  final displayName = (fromUninstall != null && fromUninstall.isNotEmpty)
      ? fromUninstall
      : (known ??
          (fromFolder.isNotEmpty ? fromFolder : 'Battle.net $productCode'));

  final uri = buildBattlenetLaunchUri(productCode: productCode);
  if (uri != null) {
    return BattlenetGameManifest(
      displayName: displayName,
      productCode: productCode,
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
      return BattlenetGameManifest(
        displayName: displayName,
        productCode: productCode,
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

/// Parses a fixture `battlenetgame-*.info` JSON blob under [installRoot].
Future<BattlenetGameManifest?> parseBattlenetInfo(
  String text, {
  required String installRoot,
  String? productCodeHint,
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

  final uid = _stringField(map, 'uid')?.trim() ??
      _stringField(map, 'internalId')?.trim() ??
      '';
  final productCode =
      (_stringField(map, 'productCode')?.trim().isNotEmpty == true
          ? _stringField(map, 'productCode')!.trim()
          : (_stringField(map, 'productId')?.trim().isNotEmpty == true
              ? _stringField(map, 'productId')!.trim()
              : (productCodeHint?.trim().isNotEmpty == true
                  ? productCodeHint!.trim()
                  : (productCodeForUid(uid) ?? ''))));
  if (productCode.isEmpty) {
    return null;
  }
  if (uid.isNotEmpty && isAgentComponent(uid)) {
    return null;
  }

  final displayRaw = _stringField(map, 'name')?.trim() ??
      _stringField(map, 'displayName')?.trim();
  final known = displayNameForProduct(
    productCode: productCode,
    uid: uid.isEmpty ? productCode : uid,
  );
  final displayName = (displayRaw != null && displayRaw.isNotEmpty)
      ? displayRaw
      : (known ?? productCode);
  if (displayName.isEmpty) {
    return null;
  }

  final uri = buildBattlenetLaunchUri(productCode: productCode);
  if (uri != null) {
    return BattlenetGameManifest(
      displayName: displayName,
      productCode: productCode,
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
      path.isAbsolute(exeRel.replaceAll('/', r'\'))
          ? exeRel.replaceAll('/', r'\')
          : path.join(root, exeRel.replaceAll('/', r'\')),
    );
    if (exe.isNotEmpty) {
      return BattlenetGameManifest(
        displayName: displayName,
        productCode: productCode,
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
      return BattlenetGameManifest(
        displayName: displayName,
        productCode: productCode,
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

/// Parses Agent `product.db` protobuf bytes into install entries.
///
/// Supports the `Database.product_installs` shape (field 1 repeated
/// ProductInstall) and a bare repeated ProductInstall / Playnite-style array.
List<BattlenetInstallEntry> parseProductDb(Uint8List bytes) {
  final out = <BattlenetInstallEntry>[];
  final seen = <String>{};

  void offer(BattlenetInstallEntry? entry) {
    if (entry == null) {
      return;
    }
    if (isAgentComponent(entry.uid)) {
      return;
    }
    final key = entry.productCode.toLowerCase();
    if (key.isEmpty || !seen.add(key)) {
      return;
    }
    out.add(entry);
  }

  for (final message in _topLevelLengthDelimited(bytes)) {
    final asInstall = _parseProductInstall(message);
    if (asInstall != null) {
      offer(asInstall);
      continue;
    }
    // Database / wrapper: walk nested length-delimited fields.
    var i = 0;
    while (i < message.length) {
      final tag = _readVarint(message, i);
      if (tag == null) {
        break;
      }
      i = tag.next;
      final field = tag.value >> 3;
      final wire = tag.value & 0x7;
      if (wire == 2) {
        final len = _readVarint(message, i);
        if (len == null) {
          break;
        }
        i = len.next;
        final end = i + len.value;
        if (end > message.length) {
          break;
        }
        final nested = Uint8List.sublistView(message, i, end);
        i = end;
        if (field == 1) {
          offer(_parseProductInstall(nested));
        }
      } else if (wire == 0) {
        final skip = _readVarint(message, i);
        if (skip == null) {
          break;
        }
        i = skip.next;
      } else if (wire == 5) {
        i += 4;
      } else if (wire == 1) {
        i += 8;
      } else {
        break;
      }
    }
  }

  // Playnite deserializes product.db as a packed array of InstalledProductInfo
  // messages (no outer Database). Also try scanning the whole buffer.
  if (out.isEmpty) {
    offer(_parseProductInstall(bytes));
    for (final message in _topLevelLengthDelimited(bytes)) {
      offer(_parseProductInstall(message));
    }
  }
  return out;
}

/// Encodes a minimal Agent-style `product.db` for fixtures / tests.
Uint8List encodeProductDb(List<BattlenetInstallEntry> installs) {
  final buffer = BytesBuilder();
  for (final entry in installs) {
    final install = _encodeProductInstall(entry);
    buffer.addByte(0x0A); // Database.product_installs = field 1, length-delim
    _writeVarint(buffer, install.length);
    buffer.add(install);
  }
  return buffer.toBytes();
}

Uint8List _encodeProductInstall(BattlenetInstallEntry entry) {
  final buffer = BytesBuilder();
  final uid = entry.uid.trim();
  final code = entry.productCode.trim();
  final path = entry.installDir.trim().replaceAll(r'\', '/');
  if (uid.isNotEmpty) {
    final raw = utf8.encode(uid);
    buffer.addByte(0x0A); // uid = 1
    _writeVarint(buffer, raw.length);
    buffer.add(raw);
  }
  if (code.isNotEmpty) {
    final raw = utf8.encode(code);
    buffer.addByte(0x12); // product_code = 2
    _writeVarint(buffer, raw.length);
    buffer.add(raw);
  }
  if (path.isNotEmpty) {
    final settings = BytesBuilder();
    final pathBytes = utf8.encode(path);
    settings.addByte(0x0A); // install_path = 1
    _writeVarint(settings, pathBytes.length);
    settings.add(pathBytes);
    final nested = settings.toBytes();
    buffer.addByte(0x1A); // settings = 3
    _writeVarint(buffer, nested.length);
    buffer.add(nested);
  }
  return buffer.toBytes();
}

BattlenetInstallEntry? _parseProductInstall(Uint8List message) {
  String? uid;
  String? productCode;
  String? installPath;
  var i = 0;
  while (i < message.length) {
    final tag = _readVarint(message, i);
    if (tag == null) {
      break;
    }
    i = tag.next;
    final field = tag.value >> 3;
    final wire = tag.value & 0x7;
    if (wire == 2) {
      final len = _readVarint(message, i);
      if (len == null) {
        break;
      }
      i = len.next;
      final end = i + len.value;
      if (end > message.length) {
        break;
      }
      final payload = Uint8List.sublistView(message, i, end);
      i = end;
      if (field == 1) {
        uid = utf8.decode(payload, allowMalformed: true).trim();
      } else if (field == 2) {
        productCode = utf8.decode(payload, allowMalformed: true).trim();
      } else if (field == 3) {
        installPath = _installPathFromSettings(payload) ?? installPath;
      }
    } else if (wire == 0) {
      final skip = _readVarint(message, i);
      if (skip == null) {
        break;
      }
      i = skip.next;
    } else if (wire == 5) {
      i += 4;
    } else if (wire == 1) {
      i += 8;
    } else {
      break;
    }
  }
  final resolvedUid = uid?.trim() ?? '';
  var resolvedCode = productCode?.trim() ?? '';
  if (resolvedCode.isEmpty && resolvedUid.isNotEmpty) {
    resolvedCode = productCodeForUid(resolvedUid) ?? '';
  }
  if (resolvedCode.isEmpty) {
    return null;
  }
  if (isAgentComponent(resolvedUid.isEmpty ? resolvedCode : resolvedUid)) {
    return null;
  }
  final dir = (installPath ?? '').trim();
  return BattlenetInstallEntry(
    uid: resolvedUid.isEmpty ? resolvedCode.toLowerCase() : resolvedUid,
    productCode: resolvedCode,
    installDir: dir.isEmpty
        ? ''
        : WindowsPaths.normalize(dir.replaceAll('/', r'\')),
    displayName: displayNameForProduct(
      productCode: resolvedCode,
      uid: resolvedUid,
    ),
  );
}

String? _installPathFromSettings(Uint8List settings) {
  var i = 0;
  while (i < settings.length) {
    final tag = _readVarint(settings, i);
    if (tag == null) {
      break;
    }
    i = tag.next;
    final field = tag.value >> 3;
    final wire = tag.value & 0x7;
    if (wire == 2) {
      final len = _readVarint(settings, i);
      if (len == null) {
        break;
      }
      i = len.next;
      final end = i + len.value;
      if (end > settings.length) {
        break;
      }
      final payload = Uint8List.sublistView(settings, i, end);
      i = end;
      if (field == 1) {
        final path = utf8.decode(payload, allowMalformed: true).trim();
        if (path.isNotEmpty) {
          return path;
        }
      }
    } else if (wire == 0) {
      final skip = _readVarint(settings, i);
      if (skip == null) {
        break;
      }
      i = skip.next;
    } else if (wire == 5) {
      i += 4;
    } else if (wire == 1) {
      i += 8;
    } else {
      break;
    }
  }
  return null;
}

List<Uint8List> _topLevelLengthDelimited(Uint8List bytes) {
  final out = <Uint8List>[];
  var i = 0;
  while (i < bytes.length) {
    final tag = _readVarint(bytes, i);
    if (tag == null) {
      break;
    }
    i = tag.next;
    final wire = tag.value & 0x7;
    if (wire == 2) {
      final len = _readVarint(bytes, i);
      if (len == null) {
        break;
      }
      i = len.next;
      final end = i + len.value;
      if (end > bytes.length) {
        break;
      }
      out.add(Uint8List.sublistView(bytes, i, end));
      i = end;
    } else if (wire == 0) {
      final skip = _readVarint(bytes, i);
      if (skip == null) {
        break;
      }
      i = skip.next;
    } else if (wire == 5) {
      i += 4;
    } else if (wire == 1) {
      i += 8;
    } else {
      break;
    }
  }
  return out;
}

({int value, int next})? _readVarint(Uint8List bytes, int start) {
  var result = 0;
  var shift = 0;
  var i = start;
  while (i < bytes.length && shift <= 35) {
    final b = bytes[i++];
    result |= (b & 0x7F) << shift;
    if ((b & 0x80) == 0) {
      return (value: result, next: i);
    }
    shift += 7;
  }
  return null;
}

void _writeVarint(BytesBuilder buffer, int value) {
  var v = value;
  while (v > 0x7F) {
    buffer.addByte((v & 0x7F) | 0x80);
    v >>= 7;
  }
  buffer.addByte(v & 0x7F);
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
  return lower == 'battle.net.exe' ||
      lower == 'battle.net helper.exe' ||
      lower == 'agent.exe' ||
      lower.contains('crash') ||
      lower.contains('unins') ||
      lower.contains('redist') ||
      lower.contains('vcredist') ||
      lower.contains('dotnet') ||
      lower.contains('setup');
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
