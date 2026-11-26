import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:homedeck/core/generated_icon.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/placeholder_png.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/epic_library.dart';
import 'package:homedeck/platform/gog_library.dart';
import 'package:homedeck/platform/rom_library.dart';
import 'package:homedeck/platform/start_menu_library.dart';
import 'package:homedeck/platform/steam_library.dart';
import 'package:homedeck/platform/battlenet_library.dart';
import 'package:homedeck/platform/ea_library.dart';
import 'package:homedeck/platform/ubisoft_library.dart';
import 'package:homedeck/platform/windows_icon_extractor.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:homedeck/platform/windows_native_bridge.dart';

typedef FilePickerFn = Future<String?> Function({
  required String label,
  required List<String> extensions,
});

/// Windows launch adapter.
///
/// Manual add: `.exe` / `.lnk`, store URIs (`steam://…`), or emulator + ROM.
/// [discover] scans Steam library folders for `steam://rungameid/…` targets.
/// [discoverStartMenu] walks Start Menu Programs for `.lnk` → exe/URI/shortcut.
/// [discoverRoms] walks a configured ROM folder for common ROM extensions.
/// [discoverEpic] reads Epic Games Launcher `*.item` manifests for
/// `com.epicgames.launcher://apps/…` (or resolved `.exe`) targets.
/// [discoverGog] reads GOG `goggame-*.info` installs for
/// `goggalaxy://openGameView/…` (or resolved `.exe`) targets.
/// [discoverUbisoft] reads Ubisoft Connect installs for
/// `uplay://launch/…` (or resolved `.exe`) targets.
/// [discoverEa] reads EA App / Origin installs for
/// `origin://launchgame/…` (or resolved `.exe`) targets.
/// [discoverBattlenet] reads Battle.net Agent / product.db installs for
/// `battlenet://…` (or resolved `.exe`) targets.
/// Icons prefer a real PE / shortcut extract into [IconCache]; generated
/// initial tiles remain the fallback (see docs/DECISIONS.md).
class WindowsAdapter implements PlatformAdapter {
  WindowsAdapter({
    WindowsIo io = const DartWindowsIo(),
    FilePickerFn? filePicker,
    WindowsIconExtractor? iconExtractor,
    SteamLibraryScanner? steamScanner,
    StartMenuScanner? startMenuScanner,
    RomFolderScanner? romScanner,
    EpicLibraryScanner? epicScanner,
    GogLibraryScanner? gogScanner,
    UbisoftLibraryScanner? ubisoftScanner,
    EaLibraryScanner? eaScanner,
    BattlenetLibraryScanner? battlenetScanner,
  }) : _io = io,
       _filePicker = filePicker ?? _defaultPicker,
       _iconExtractor = iconExtractor ?? Win32IconExtractor(),
       _steamScanner = steamScanner ?? SteamLibraryScanner(io: io),
       _startMenuScanner = startMenuScanner ?? StartMenuScanner(io: io),
       _romScanner = romScanner,
       _epicScanner = epicScanner ?? EpicLibraryScanner(io: io),
       _gogScanner = gogScanner ?? GogLibraryScanner(io: io),
       _ubisoftScanner = ubisoftScanner ?? UbisoftLibraryScanner(io: io),
       _eaScanner = eaScanner ?? EaLibraryScanner(io: io),
       _battlenetScanner =
           battlenetScanner ?? BattlenetLibraryScanner(io: io);

  final WindowsIo _io;
  final FilePickerFn _filePicker;
  final WindowsIconExtractor _iconExtractor;
  final SteamLibraryScanner _steamScanner;
  final StartMenuScanner _startMenuScanner;
  final RomFolderScanner? _romScanner;
  final EpicLibraryScanner _epicScanner;
  final GogLibraryScanner _gogScanner;
  final UbisoftLibraryScanner _ubisoftScanner;
  final EaLibraryScanner _eaScanner;
  final BattlenetLibraryScanner _battlenetScanner;

  static Future<String?> _defaultPicker({
    required String label,
    required List<String> extensions,
  }) async {
    // Prefer classic GetOpenFileName via the runner. Ally Phase2 @bdd3ba1 /
    // c8a379f: file_selector's IFileDialog is not FindWindow-able as "Open"
    // → harness false-PASS add_exe_tile while Dart never got a path
    // (apps=[], only _homedeck_ready.png). OFN is #32770 titled "Open".
    try {
      return await WindowsNativeBridge.pickOpenFile(
        label: label,
        extensions: extensions,
        confirmButtonText: 'Add to HomeDeck',
      );
    } on MissingPluginException {
      // Widget tests / non-runner hosts.
    } on PlatformException {
      // Fall through to file_selector.
    }
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: label, extensions: extensions),
      ],
      confirmButtonText: 'Add to HomeDeck',
    );
    return file?.path;
  }

  @override
  AppPlatform get platform => AppPlatform.windows;

  @override
  Future<List<DiscoveredApp>> discover() => _steamScanner.discover();

  @override
  Future<List<DiscoveredApp>> discoverStartMenu() =>
      _startMenuScanner.discover();

  @override
  Future<List<DiscoveredApp>> discoverRoms({
    String? romRoot,
    String? emulator,
  }) {
    final scanner = _romScanner ??
        RomFolderScanner(
          io: _io,
          configuredRomRoot: romRoot,
          romRoots: () => RomFolderScanner.defaultRomRoots(configured: romRoot),
          emulatorPath: () {
            final forced = RomFolderScanner.defaultEmulatorPath();
            if (forced != null && forced.isNotEmpty) {
              return forced;
            }
            final injected = emulator?.trim();
            if (injected != null && injected.isNotEmpty) {
              return WindowsPaths.normalize(injected);
            }
            return null;
          },
        );
    return scanner.discover();
  }

  @override
  Future<List<DiscoveredApp>> discoverEpic() => _epicScanner.discover();

  @override
  Future<List<DiscoveredApp>> discoverGog() => _gogScanner.discover();

  @override
  Future<List<DiscoveredApp>> discoverUbisoft() => _ubisoftScanner.discover();

  @override
  Future<List<DiscoveredApp>> discoverEa() => _eaScanner.discover();

  @override
  Future<List<DiscoveredApp>> discoverBattlenet() =>
      _battlenetScanner.discover();

  @override
  Future<String?> resolveIcon({
    required LaunchTarget target,
    required IconCache cache,
    required String appId,
    required String displayName,
  }) async {
    // Disk-first with a canned PNG — return as soon as icons/<id>.png
    // exists. GPU generate + Win32 extract upgrade in the background so
    // Ally's watcher (and addFromPicker) never wait on dart:ui / channel.
    final ref = await cache.writePng(appId, placeholderPng);
    unawaited(_upgradeIconArt(
      target: target,
      cache: cache,
      appId: appId,
      displayName: displayName,
    ));
    return ref;
  }

  Future<void> _upgradeIconArt({
    required LaunchTarget target,
    required IconCache cache,
    required String appId,
    required String displayName,
  }) async {
    try {
      final generated = await generateInitialIcon(
        displayName: displayName,
        key: appId,
      ).timeout(const Duration(milliseconds: 800), onTimeout: () => placeholderPng);
      if (generated.isNotEmpty) {
        await cache.writePng(appId, generated);
      }
    } catch (_) {
      // Keep placeholder already on disk.
    }

    try {
      final extracted = await _tryExtractIcon(target).timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (extracted != null && extracted.isNotEmpty) {
        await cache.writePng(appId, extracted);
      }
    } catch (_) {
      // Keep whatever is already on disk.
    }
  }

  /// Best-effort PE / `.lnk` extract. Returns `null` for URIs, missing files,
  /// non-Windows hosts, or any Win32 failure so callers keep the generated tile.
  Future<Uint8List?> _tryExtractIcon(LaunchTarget target) async {
    if (target.kind == LaunchTargetKind.windowsUri ||
        WindowsPaths.isLaunchUri(target.value)) {
      return null;
    }
    final path = target.value.trim();
    if (path.isEmpty) {
      return null;
    }
    if (!WindowsPaths.isExecutable(path) &&
        !WindowsPaths.isShortcut(path) &&
        target.kind != LaunchTargetKind.windowsEmulated) {
      return null;
    }
    // Bad / missing paths must not touch Shell extract (Ally "bad path" case).
    try {
      if (!await _io.fileExists(path)) {
        return null;
      }
    } catch (_) {
      return null;
    }
    try {
      return await _iconExtractor.extractPng(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<LaunchFailure?> validateTarget(LaunchTarget target) async {
    if (target.platform != AppPlatform.windows) {
      return LaunchFailure.launchFailed(
        targetValue: target.value,
        detail: 'This tile has no Windows launch target.',
      );
    }
    if (target.kind == LaunchTargetKind.windowsUri ||
        WindowsPaths.isLaunchUri(target.value)) {
      return _validateUri(target.value);
    }
    if (target.kind == LaunchTargetKind.windowsEmulated) {
      final emulator = await _validatePath(target.value);
      if (emulator != null) {
        return emulator;
      }
      final rom = target.romPath?.trim() ?? '';
      if (rom.isEmpty) {
        return LaunchFailure.missingFile(
          targetValue: rom,
          detail: 'No ROM file is set for this emulated game.',
        );
      }
      return _validatePath(rom);
    }
    return _validatePath(target.value);
  }

  LaunchFailure? _validateUri(String raw) {
    final trimmed = raw.trim();
    if (!WindowsPaths.isLaunchUri(trimmed)) {
      return LaunchFailure.launchFailed(
        targetValue: trimmed,
        detail: 'This is not a valid launch URI.',
      );
    }
    return null;
  }

  Future<LaunchFailure?> _validatePath(String raw) async {
    final path = raw.trim();
    if (path.isEmpty) {
      return LaunchFailure.missingFile(targetValue: path);
    }

    if (WindowsPaths.looksLikeVolumePath(path)) {
      final root = WindowsPaths.rootPrefix(path);
      try {
        final ready = await _io.volumeReady(root);
        if (!ready) {
          return LaunchFailure.removedDrive(targetValue: path);
        }
      } on FileSystemException catch (error) {
        return _mapIoError(error, path);
      }
    }

    try {
      final exists = await _io.fileExists(path);
      if (!exists) {
        return LaunchFailure.missingFile(targetValue: path);
      }
      await _io.checkReadable(path);
    } on FileSystemException catch (error) {
      return _mapIoError(error, path);
    }
    return null;
  }

  @override
  Future<LaunchOutcome> launch(LaunchTarget target) async {
    final failure = await validateTarget(target);
    if (failure != null) {
      return failure;
    }
    try {
      // Runner MethodChannel ShellExecuteW first (via DartWindowsIo), then
      // Dart FFI / CreateProcess / cmd-start. Ally 2417533 Dart-only
      // ShellExecute never spawned notepad after Enter.
      await _io.startDetached(
        executable: target.value,
        arguments: target.resolvedArguments,
        shortcut: true,
      );
      return const LaunchSuccess();
    } on FileSystemException catch (error) {
      return _mapIoError(error, target.value);
    } catch (error) {
      return LaunchFailure.launchFailed(
        targetValue: target.value,
        detail: error.toString(),
      );
    }
  }

  @override
  Future<String?> pickFile({
    required String label,
    required List<String> extensions,
  }) {
    return _filePicker(label: label, extensions: extensions);
  }

  @override
  Future<PickedLaunch?> pickLaunchTarget() async {
    final path = await pickFile(
      label: 'Windows apps',
      extensions: const ['exe', 'lnk'],
    );
    return pickedLaunchFromPath(path);
  }

  /// Parse a path or URI the runner already chose (native A / HOMEDECK_ADD_PATH).
  static PickedLaunch? pickedLaunchFromPath(String? path) {
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final trimmed = path.trim();
    if (WindowsPaths.isLaunchUri(trimmed)) {
      return PickedLaunch(
        displayName: uriDisplayName(trimmed),
        target: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsUri,
          value: trimmed,
        ),
      );
    }
    if (!WindowsPaths.isSupportedLaunchFile(trimmed)) {
      return null;
    }
    final kind = WindowsPaths.isShortcut(trimmed)
        ? LaunchTargetKind.windowsShortcut
        : LaunchTargetKind.windowsExecutable;
    return PickedLaunch(
      displayName: WindowsPaths.basenameWithoutExtension(trimmed),
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: kind,
        value: trimmed,
      ),
    );
  }

  static String uriDisplayName(String uri) {
    final parsed = Uri.tryParse(uri.trim());
    if (parsed == null) {
      return uri.trim();
    }
    final host = parsed.host;
    if (host.isNotEmpty) {
      return host;
    }
    final path = parsed.path.replaceAll('/', '').trim();
    if (path.isNotEmpty) {
      return path;
    }
    return parsed.scheme;
  }

  LaunchFailure _mapIoError(FileSystemException error, String path) {
    final code = error.osError?.errorCode;
    // Windows: 5 = ERROR_ACCESS_DENIED. POSIX: 13 = EACCES.
    if (code == 5 || code == 13) {
      return LaunchFailure.permissionDenied(
        targetValue: path,
        detail: error.message,
      );
    }
    // Windows: 15 = ERROR_INVALID_DRIVE, 21 = ERROR_NOT_READY.
    if (code == 15 || code == 21) {
      return LaunchFailure.removedDrive(
        targetValue: path,
        detail: error.message,
      );
    }
    return LaunchFailure.missingFile(
      targetValue: path,
      detail: error.message,
    );
  }
}
