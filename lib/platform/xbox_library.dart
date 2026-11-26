import 'dart:convert';
import 'dart:io';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:path/path.dart' as p;

/// One installed Xbox / Microsoft Store / Game Pass PC title.
class XboxInstallEntry {
  const XboxInstallEntry({
    required this.installDir,
    this.displayName,
    this.productId,
    this.packageFamilyName,
    this.applicationId,
    this.aumid,
    this.uri,
  });

  final String installDir;
  final String? displayName;

  /// Store / product id for `msxbox://game/?id=…` when known.
  final String? productId;

  /// AppX package family name (`Name_PublisherHash`).
  final String? packageFamilyName;

  /// AppX application id (often `App`).
  final String? applicationId;

  /// Full AUMID (`PackageFamilyName!ApplicationId`) when known.
  final String? aumid;

  /// Explicit launch URI from a fixture (`msxbox:` / `xbox:` /
  /// `ms-windows-store:` / `shell:AppsFolder\…`).
  final String? uri;
}

/// Scans Xbox / Microsoft Store / Game Pass PC installs and emits
/// [DiscoveredApp] rows.
///
/// Roots come from optional `HOMEDECK_XBOX_ROOT` (Ally / CI fixture),
/// GamingRoot markers (`.GamingRoot` + `XboxGames`), common
/// `XboxGames` / `ModifiableWindowsApps` candidates, and best-effort
/// Gaming Services registry hints. Prefer `msxbox:` / `xbox:` /
/// `ms-windows-store:` when a product / store id (or explicit URI) is
/// present; else AppX AUMID via `shell:AppsFolder\{PFN}!{AppId}`; else a
/// resolved `.exe` under the install / `Content` folder.
///
/// Fixture folders may ship `xboxgame-*.info` JSON (name + productId /
/// aumid / packageFamilyName / applicationId / uri) or real title folders
/// with `MicrosoftGame.config` / `appxmanifest.xml`.
///
/// **Limits (honest):** `%ProgramFiles%\WindowsApps` is often ACL-locked
/// so many Store packages are invisible without elevation. UWP / Game Pass
/// titles may only launch via package activation (Store URI or AUMID) —
/// raw `.exe` is best-effort and frequently fails. Owned-but-not-installed
/// Game Pass catalog entries are not discoverable without Xbox sign-in APIs
/// (out of scope).
///
/// Does **not** invent games-only filtering — every launchable install /
/// info / config becomes a Library tile (By app → Xbox / Microsoft Store).
class XboxLibraryScanner {
  XboxLibraryScanner({
    required WindowsIo io,
    List<String> Function()? candidateRoots,
    Future<List<XboxInstallEntry>> Function()? registryInstalls,
    p.Context? pathContext,
  }) : _io = io,
       _candidateRoots = candidateRoots ?? defaultCandidateRoots,
       _registryInstalls = registryInstalls ?? queryInstallsFromRegistry,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _candidateRoots;
  final Future<List<XboxInstallEntry>> Function() _registryInstalls;
  final p.Context _path;

  /// Common Xbox / GamingRoot / package-root guesses (no hard-coded drive).
  ///
  /// Optional `HOMEDECK_XBOX_ROOT` is tried first: a fixture tree with
  /// `xboxgame-*.info`, title folders (`MicrosoftGame.config` /
  /// `appxmanifest.xml`), or an `XboxGames` / `Content` layout.
  static List<String> defaultCandidateRoots() {
    final env = Platform.environment;
    final out = <String>[];
    final path = WindowsPaths.context;
    final forced = env['HOMEDECK_XBOX_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      final normalized = WindowsPaths.normalize(forced);
      out.add(normalized);
      out.add(path.join(normalized, 'XboxGames'));
      out.add(path.join(normalized, 'Games'));
      out.add(path.join(normalized, 'games'));
      out.add(path.join(normalized, 'Content'));
      out.add(path.join(normalized, 'ModifiableWindowsApps'));
    }

    void addUnder(String? base) {
      if (base == null || base.trim().isEmpty) {
        return;
      }
      final root = WindowsPaths.normalize(base);
      out.add(path.join(root, 'XboxGames'));
      out.add(path.join(root, 'ModifiableWindowsApps'));
      // WindowsApps is often ACL-locked; still offer it best-effort.
      out.add(path.join(root, 'WindowsApps'));
    }

    addUnder(env['ProgramFiles(x86)']);
    addUnder(env['ProgramFiles']);
    addUnder(env['PROGRAMFILES(X86)']);
    addUnder(env['PROGRAMFILES']);

    final systemDrive = env['SystemDrive']?.trim();
    if (systemDrive != null && systemDrive.isNotEmpty) {
      final driveRoot = '$systemDrive\\';
      out.add(path.join(driveRoot, 'XboxGames'));
      out.add(
        path.join(driveRoot, 'Program Files', 'ModifiableWindowsApps'),
      );
      out.add(path.join(driveRoot, 'Program Files', 'WindowsApps'));
      // GamingRoot marker lives at the drive root; XboxGames beside it.
      out.add(driveRoot);
    }

    // Extra fixed letters when present (GamingRoot on D:/E: etc.).
    for (final letter in const ['D', 'E', 'F', 'G']) {
      out.add('$letter:\\');
      out.add(path.join('$letter:\\', 'XboxGames'));
    }
    return out;
  }

  /// Best-effort Gaming Services / PackageRepository install dirs via `reg`.
  ///
  /// Many Game Pass titles never write a useful Uninstall entry; this is a
  /// hint only. Primary discovery remains folder / config / fixture scan.
  static Future<List<XboxInstallEntry>> queryInstallsFromRegistry() async {
    if (!Platform.isWindows) {
      return const [];
    }
    final out = <XboxInstallEntry>[];
    final seen = <String>{};

    for (final rootKey in const [
      r'HKLM\SOFTWARE\Microsoft\GamingServices\PackageRepository\Root',
      r'HKLM\SOFTWARE\WOW6432Node\Microsoft\GamingServices\PackageRepository\Root',
    ]) {
      final rootPath = await _queryRegSz(
        [
          ['query', rootKey, '/ve'],
          ['query', rootKey, '/v', ''],
        ],
        valueName: '(Default)',
        alternateNames: const ['', '(Default)'],
      );
      if (rootPath == null || rootPath.isEmpty) {
        continue;
      }
      final normalized = WindowsPaths.normalize(rootPath);
      if (!seen.add(normalized.toLowerCase())) {
        continue;
      }
      out.add(XboxInstallEntry(installDir: normalized));
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
        // Default value lines sometimes omit the name column.
        final fallback = _parseRegDefaultSz(stdout);
        if (fallback != null) {
          return fallback;
        }
      } catch (_) {
        // Missing reg.exe or access denied — try next key.
      }
    }
    return null;
  }

  /// Pulls a REG_SZ data column from a `reg query` stdout dump.
  static String? parseRegQuerySz(String stdout, String valueName) {
    final needle = valueName.trim();
    if (needle.isEmpty || needle == '(Default)') {
      return _parseRegDefaultSz(stdout);
    }
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (!trimmed.toLowerCase().contains(needle.toLowerCase())) {
        continue;
      }
      final match = RegExp(
        '${RegExp.escape(needle)}\\s+REG_\\w+\\s+(.+)\$',
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

  static String? _parseRegDefaultSz(String stdout) {
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final match = RegExp(
        r'(?:\(Default\)|\(Par défaut\))?\s*REG_\w+\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (match == null) {
        continue;
      }
      final value = match.group(1)?.trim();
      if (value != null &&
          value.isNotEmpty &&
          value.toLowerCase() != '(value not set)') {
        return WindowsPaths.normalize(value.replaceAll('/', r'\'));
      }
    }
    return null;
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
      // WindowsApps (and similar) often exists but is ACL-locked; one
      // unreadable root must not abort fixture / XboxGames discovery.
      try {
        await _collectInfoFiles(root, byKey);
        await _collectConfigFolder(root, byKey);

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
          await _collectConfigFolder(child, byKey);

          // XboxGames\<Title>\Content layout.
          final content = _path.join(child, 'Content');
          if (await _io.directoryExists(content)) {
            await _collectInfoFiles(content, byKey);
            await _collectConfigFolder(content, byKey);
          }
        }
      } catch (_) {
        // Access denied / unreadable — skip this root, keep scanning others.
        continue;
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
    List<String> names;
    try {
      names = await _io.listDirectory(folder);
    } catch (_) {
      // ACL-denied / unreadable folder — caller may still scan siblings.
      return;
    }
    for (final name in names) {
      if (!_isXboxInfoFile(name)) {
        continue;
      }
      final filePath = _path.join(folder, name);
      String text;
      try {
        text = await _io.readTextFile(filePath);
      } catch (_) {
        continue;
      }
      final idHint = productIdFromInfoFileName(name);
      final parsed = await parseXboxInfo(
        text,
        installRoot: folder,
        productIdHint: idHint,
        pathContext: _path,
        io: _io,
      );
      if (parsed == null) {
        continue;
      }
      byKey.putIfAbsent(parsed.dedupeKey, () => parsed.toDiscoveredApp());
    }
  }

  Future<void> _collectConfigFolder(
    String folder,
    Map<String, DiscoveredApp> byKey,
  ) async {
    final configPath = _path.join(folder, 'MicrosoftGame.config');
    final manifestPath = _path.join(folder, 'appxmanifest.xml');
    final hasConfig = await _io.fileExists(configPath);
    final hasManifest = await _io.fileExists(manifestPath);
    if (!hasConfig && !hasManifest) {
      return;
    }

    String? configText;
    String? manifestText;
    if (hasConfig) {
      try {
        configText = await _io.readTextFile(configPath);
      } catch (_) {
        configText = null;
      }
    }
    if (hasManifest) {
      try {
        manifestText = await _io.readTextFile(manifestPath);
      } catch (_) {
        manifestText = null;
      }
    }

    final parsed = await parseXboxPackageFiles(
      configXml: configText,
      manifestXml: manifestText,
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
      // Drive roots with a GamingRoot marker → also scan XboxGames beside it.
      final gamingRoot = _path.join(candidate, '.GamingRoot');
      if (await _io.fileExists(gamingRoot)) {
        offer(_path.join(candidate, 'XboxGames'));
      }
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

bool _isXboxInfoFile(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('xboxgame-') && lower.endsWith('.info');
}

bool _skipDirName(String name) {
  final lower = name.toLowerCase();
  return lower == 'cache' ||
      lower == 'data' ||
      lower == 'logs' ||
      lower == 'crashes' ||
      lower == 'microsoft.gamingapp_8wekyb3d8bbwe' ||
      lower.startsWith('.');
}

/// Pulls `{id}` from `xboxgame-{id}.info`.
String? productIdFromInfoFileName(String name) {
  final match = RegExp(
    r'^xboxgame-([0-9A-Za-z]+)\.info$',
    caseSensitive: false,
  ).firstMatch(name.trim());
  return match?.group(1);
}

/// Parsed Xbox / Store install used for discovery.
class XboxGameManifest {
  const XboxGameManifest({
    required this.displayName,
    required this.launchTarget,
    this.productId = '',
  });

  final String displayName;
  final LaunchTarget launchTarget;
  final String productId;

  String get dedupeKey {
    final value = launchTarget.value.trim().toLowerCase();
    if (value.isNotEmpty) {
      return value;
    }
    return productId.toLowerCase();
  }

  DiscoveredApp toDiscoveredApp() {
    return DiscoveredApp(
      displayName: displayName,
      kind: TileKind.native,
      target: launchTarget,
    );
  }
}

/// Builds `msxbox://game/?id={productId}` when [productId] is set.
String? buildMsXboxLaunchUri({required String productId}) {
  final id = productId.trim();
  if (id.isEmpty) {
    return null;
  }
  return 'msxbox://game/?id=$id';
}

/// Builds `ms-windows-store://pdp/?ProductId={productId}` fallback URI.
String? buildMsWindowsStoreLaunchUri({required String productId}) {
  final id = productId.trim();
  if (id.isEmpty) {
    return null;
  }
  return 'ms-windows-store://pdp/?ProductId=$id';
}

/// Builds `shell:AppsFolder\{packageFamilyName}!{applicationId}` AUMID URI.
String? buildXboxAumidUri({
  required String packageFamilyName,
  required String applicationId,
}) {
  final pfn = packageFamilyName.trim();
  final appId = applicationId.trim();
  if (pfn.isEmpty || appId.isEmpty) {
    return null;
  }
  if (pfn.contains('!') || appId.contains('!')) {
    return null;
  }
  return 'shell:AppsFolder\\$pfn!$appId';
}

/// Normalizes an explicit AUMID or `shell:AppsFolder\…` string.
String? normalizeXboxAumidUri(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  final lower = value.toLowerCase();
  if (lower.startsWith('shell:')) {
    return value;
  }
  if (value.contains('!')) {
    return 'shell:AppsFolder\\$value';
  }
  return null;
}

/// Maps an [XboxInstallEntry] to a launchable manifest.
Future<XboxGameManifest?> installEntryToManifest(
  XboxInstallEntry entry, {
  p.Context? pathContext,
  WindowsIo? io,
}) async {
  final path = pathContext ?? WindowsPaths.context;
  final installDir = WindowsPaths.normalize(
    entry.installDir.trim().replaceAll('/', r'\'),
  );
  final fromName = entry.displayName?.trim();
  final fromFolder = installDir.isNotEmpty
      ? path.basename(installDir.replaceAll(RegExp(r'[\\/]+$'), ''))
      : '';
  final displayName = (fromName != null && fromName.isNotEmpty)
      ? fromName
      : (fromFolder.isNotEmpty ? fromFolder : 'Xbox title');

  final explicit = entry.uri?.trim();
  if (explicit != null &&
      explicit.isNotEmpty &&
      WindowsPaths.isLaunchUri(explicit)) {
    return XboxGameManifest(
      displayName: displayName,
      productId: entry.productId?.trim() ?? '',
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: explicit,
      ),
    );
  }

  final productId = entry.productId?.trim() ?? '';
  final msxbox = buildMsXboxLaunchUri(productId: productId);
  if (msxbox != null) {
    return XboxGameManifest(
      displayName: displayName,
      productId: productId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: msxbox,
      ),
    );
  }

  final aumidUri = normalizeXboxAumidUri(entry.aumid) ??
      buildXboxAumidUri(
        packageFamilyName: entry.packageFamilyName ?? '',
        applicationId: entry.applicationId ?? 'App',
      );
  if (aumidUri != null) {
    return XboxGameManifest(
      displayName: displayName,
      productId: productId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: aumidUri,
      ),
    );
  }

  if (io != null && installDir.isNotEmpty) {
    final exe = await findPrimaryExe(installDir, io: io, pathContext: path);
    if (exe != null && exe.isNotEmpty) {
      return XboxGameManifest(
        displayName: displayName,
        productId: productId,
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

/// Parses a fixture `xboxgame-*.info` JSON blob under [installRoot].
Future<XboxGameManifest?> parseXboxInfo(
  String text, {
  required String installRoot,
  String? productIdHint,
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

  final productId = (_stringField(map, 'productId')?.trim().isNotEmpty == true
          ? _stringField(map, 'productId')!.trim()
          : (_stringField(map, 'storeId')?.trim().isNotEmpty == true
              ? _stringField(map, 'storeId')!.trim()
              : (productIdHint?.trim() ?? '')));
  final displayRaw = _stringField(map, 'name')?.trim() ??
      _stringField(map, 'displayName')?.trim();
  final displayName = (displayRaw != null && displayRaw.isNotEmpty)
      ? displayRaw
      : (productId.isNotEmpty ? productId : '');
  if (displayName.isEmpty) {
    return null;
  }

  final explicitUri = _stringField(map, 'uri')?.trim() ??
      _stringField(map, 'launchUri')?.trim();
  if (explicitUri != null &&
      explicitUri.isNotEmpty &&
      WindowsPaths.isLaunchUri(explicitUri)) {
    return XboxGameManifest(
      displayName: displayName,
      productId: productId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: explicitUri,
      ),
    );
  }

  final msxbox = buildMsXboxLaunchUri(productId: productId);
  if (msxbox != null) {
    return XboxGameManifest(
      displayName: displayName,
      productId: productId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: msxbox,
      ),
    );
  }

  final scheme = _stringField(map, 'scheme')?.trim().toLowerCase();
  if (scheme == 'xbox' || scheme == 'msxbox' || scheme == 'ms-windows-store') {
    final id = productId.isNotEmpty ? productId : displayName;
    if (scheme == 'ms-windows-store') {
      final storeUri = buildMsWindowsStoreLaunchUri(productId: id);
      if (storeUri != null) {
        return XboxGameManifest(
          displayName: displayName,
          productId: id,
          launchTarget: LaunchTarget(
            platform: AppPlatform.windows,
            kind: LaunchTargetKind.windowsUri,
            value: storeUri,
          ),
        );
      }
    } else {
      final uri = buildMsXboxLaunchUri(productId: id);
      if (uri != null) {
        return XboxGameManifest(
          displayName: displayName,
          productId: id,
          launchTarget: LaunchTarget(
            platform: AppPlatform.windows,
            kind: LaunchTargetKind.windowsUri,
            value: uri,
          ),
        );
      }
    }
  }

  final pfn = _stringField(map, 'packageFamilyName')?.trim() ??
      _stringField(map, 'pfn')?.trim() ??
      '';
  final appId = _stringField(map, 'applicationId')?.trim() ??
      _stringField(map, 'appId')?.trim() ??
      'App';
  final aumidUri = normalizeXboxAumidUri(_stringField(map, 'aumid')) ??
      buildXboxAumidUri(packageFamilyName: pfn, applicationId: appId);
  if (aumidUri != null) {
    return XboxGameManifest(
      displayName: displayName,
      productId: productId,
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: aumidUri,
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
      return XboxGameManifest(
        displayName: displayName,
        productId: productId.isEmpty ? displayName : productId,
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
      return XboxGameManifest(
        displayName: displayName,
        productId: productId.isEmpty ? displayName : productId,
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

/// Parses `MicrosoftGame.config` / `appxmanifest.xml` under an install folder.
Future<XboxGameManifest?> parseXboxPackageFiles({
  String? configXml,
  String? manifestXml,
  required String installRoot,
  p.Context? pathContext,
  WindowsIo? io,
}) async {
  final path = pathContext ?? WindowsPaths.context;
  final config = configXml ?? '';
  final manifest = manifestXml ?? '';
  if (config.trim().isEmpty && manifest.trim().isEmpty) {
    return null;
  }

  final storeId = _xmlTagText(config, 'StoreId') ??
      _xmlTagText(manifest, 'StoreId') ??
      '';
  final displayName = _xmlAttr(
        _xmlFirstElement(config, 'ShellVisuals') ?? '',
        'DefaultDisplayName',
      ) ??
      _xmlTagText(manifest, 'DisplayName') ??
      _xmlTagText(config, 'DisplayName') ??
      path.basename(
        WindowsPaths.normalize(installRoot).replaceAll(RegExp(r'[\\/]+$'), ''),
      );
  if (displayName.trim().isEmpty) {
    return null;
  }

  final identity = _xmlFirstElement(manifest, 'Identity') ??
      _xmlFirstElement(config, 'Identity') ??
      '';
  final packageName = _xmlAttr(identity, 'Name') ?? '';
  final appElement = _xmlFirstElement(manifest, 'Application') ?? '';
  final applicationId = _xmlAttr(appElement, 'Id') ??
      _xmlAttr(_xmlFirstElement(config, 'Executable') ?? '', 'Id') ??
      'App';

  // Prefer Store / msxbox URI when StoreId is present.
  final msxbox = buildMsXboxLaunchUri(productId: storeId);
  if (msxbox != null) {
    return XboxGameManifest(
      displayName: displayName.trim(),
      productId: storeId.trim(),
      launchTarget: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: msxbox,
      ),
    );
  }

  // AUMID needs Package Family Name. Without publisher hash we cannot
  // synthesize PFN from Name alone — fall through to .exe best-effort.
  // Fixtures should supply packageFamilyName / aumid / productId explicitly.
  if (packageName.contains('_') && packageName.split('_').length >= 2) {
    // Already looks like a family name (Name_Hash).
    final aumid = buildXboxAumidUri(
      packageFamilyName: packageName,
      applicationId: applicationId,
    );
    if (aumid != null) {
      return XboxGameManifest(
        displayName: displayName.trim(),
        productId: storeId.trim(),
        launchTarget: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsUri,
          value: aumid,
        ),
      );
    }
  }

  if (io != null) {
    final root = WindowsPaths.normalize(installRoot.replaceAll('/', r'\'));
    final exe = await findPrimaryExe(root, io: io, pathContext: path);
    if (exe != null && exe.isNotEmpty) {
      return XboxGameManifest(
        displayName: displayName.trim(),
        productId: storeId.trim().isNotEmpty
            ? storeId.trim()
            : displayName.trim(),
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

/// Picks a shallow launchable `.exe` under [installRoot] (or `Content\`).
Future<String?> findPrimaryExe(
  String installRoot, {
  required WindowsIo io,
  p.Context? pathContext,
}) async {
  final path = pathContext ?? WindowsPaths.context;
  final root = WindowsPaths.normalize(installRoot.replaceAll('/', r'\'));
  if (root.isEmpty) {
    return null;
  }

  Future<String?> scan(String folder) async {
    if (!await io.directoryExists(folder)) {
      return null;
    }
    List<String> names;
    try {
      names = await io.listDirectory(folder);
    } catch (_) {
      return null;
    }
    String? first;
    for (final name in names) {
      if (!name.toLowerCase().endsWith('.exe')) {
        continue;
      }
      if (_skipExeName(name)) {
        continue;
      }
      final full = WindowsPaths.normalize(path.join(folder, name));
      first ??= full;
      final base = path.basenameWithoutExtension(folder).toLowerCase();
      if (base.isNotEmpty &&
          base != 'content' &&
          name.toLowerCase().contains(base)) {
        return full;
      }
    }
    return first;
  }

  final direct = await scan(root);
  if (direct != null) {
    return direct;
  }
  return scan(path.join(root, 'Content'));
}

bool _skipExeName(String name) {
  final lower = name.toLowerCase();
  return lower.contains('crash') ||
      lower.contains('unins') ||
      lower.contains('redist') ||
      lower.contains('vcredist') ||
      lower.contains('dotnet') ||
      lower.contains('easyanticheat') ||
      lower == 'gamelaunchhelper.exe';
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

String? _xmlTagText(String xml, String tag) {
  if (xml.trim().isEmpty) {
    return null;
  }
  final match = RegExp(
    '<$tag(?:\\s[^>]*)?>([^<]*)</$tag>',
    caseSensitive: false,
  ).firstMatch(xml);
  final value = match?.group(1)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  // Skip resource-style placeholders like ms-resource:…
  if (value.toLowerCase().startsWith('ms-resource:')) {
    return null;
  }
  return value;
}

String? _xmlFirstElement(String xml, String tag) {
  if (xml.trim().isEmpty) {
    return null;
  }
  final match = RegExp(
    '<$tag\\b[^>]*(?:/>|>)',
    caseSensitive: false,
  ).firstMatch(xml);
  return match?.group(0);
}

String? _xmlAttr(String element, String name) {
  if (element.trim().isEmpty) {
    return null;
  }
  final match = RegExp(
    '\\b${RegExp.escape(name)}\\s*=\\s*"([^"]*)"',
    caseSensitive: false,
  ).firstMatch(element);
  final value = match?.group(1)?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value.toLowerCase().startsWith('ms-resource:')) {
    return null;
  }
  return value;
}
