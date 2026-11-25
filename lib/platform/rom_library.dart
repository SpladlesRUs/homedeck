import 'dart:io';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:path/path.dart' as p;

/// Common ROM / disc-image extensions scanned under the configured ROM root.
///
/// Kept in one place so Ally fixtures and Settings copy stay aligned. Trim
/// here if a future pass needs a tighter list — do not invent console maps.
const List<String> kRomExtensions = [
  'iso',
  'nsp',
  'xci',
  'gba',
  'nds',
  '3ds',
  'cia',
  'wbfs',
  'rvz',
  'chd',
  'zip',
];

/// Scans a configured ROM folder for common ROM files as emulated tiles.
///
/// Root resolution order: optional `HOMEDECK_ROM_ROOT` (Ally / CI fixture),
/// then the Settings-persisted [configuredRomRoot]. Emulator resolution:
/// optional `HOMEDECK_EMULATOR`, then an injected [emulatorPath] (typically
/// the single obvious emulator `.exe` already in the library), else empty
/// so the user can finish the tile via Manual Add / edit.
class RomFolderScanner {
  RomFolderScanner({
    required WindowsIo io,
    List<String> Function()? romRoots,
    String? Function()? emulatorPath,
    p.Context? pathContext,
    this.configuredRomRoot,
  }) : _io = io,
       _romRoots = romRoots ?? (() => defaultRomRoots(configured: configuredRomRoot)),
       _emulatorPath = emulatorPath ?? defaultEmulatorPath,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _romRoots;
  final String? Function() _emulatorPath;
  final p.Context _path;

  /// Settings-persisted ROM folder when env is unset (optional).
  final String? configuredRomRoot;

  /// Extensions matched (lowercase, no dot). Exposed for tests / Settings.
  static List<String> get extensions => List<String>.unmodifiable(kRomExtensions);

  /// `HOMEDECK_ROM_ROOT` first, else [configured] from Settings.
  static List<String> defaultRomRoots({String? configured}) {
    final env = Platform.environment;
    final forced = env['HOMEDECK_ROM_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      return [WindowsPaths.normalize(forced)];
    }
    final root = configured?.trim();
    if (root != null && root.isNotEmpty) {
      return [WindowsPaths.normalize(root)];
    }
    return const [];
  }

  /// Optional `HOMEDECK_EMULATOR` absolute `.exe` path.
  static String? defaultEmulatorPath() {
    final forced = Platform.environment['HOMEDECK_EMULATOR']?.trim();
    if (forced == null || forced.isEmpty) {
      return null;
    }
    return WindowsPaths.normalize(forced);
  }

  Future<List<DiscoveredApp>> discover() async {
    final roots = _romRoots();
    if (roots.isEmpty) {
      return const [];
    }

    final emulator = (_emulatorPath()?.trim() ?? '');
    final normalizedEmu = emulator.isEmpty
        ? ''
        : WindowsPaths.normalize(emulator);

    final byRom = <String, DiscoveredApp>{};
    for (final root in roots) {
      if (!await _io.directoryExists(root)) {
        continue;
      }
      await _walk(root, byRom, normalizedEmu);
    }

    final list = byRom.values.toList(growable: false)
      ..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
    return list;
  }

  Future<void> _walk(
    String directory,
    Map<String, DiscoveredApp> byRom,
    String emulator,
  ) async {
    final names = await _io.listDirectory(directory);
    for (final name in names) {
      if (name == '.' || name == '..') {
        continue;
      }
      final full = _path.join(directory, name);
      final lower = name.toLowerCase();
      final dot = lower.lastIndexOf('.');
      if (dot >= 0) {
        final ext = lower.substring(dot + 1);
        if (kRomExtensions.contains(ext) && await _io.fileExists(full)) {
          final romPath = WindowsPaths.normalize(full);
          final key = romPath.toLowerCase();
          byRom.putIfAbsent(
            key,
            () => DiscoveredApp(
              displayName: WindowsPaths.basenameWithoutExtension(name).trim(),
              kind: TileKind.emulated,
              target: LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsEmulated,
                value: emulator,
                romPath: romPath,
                argsTemplate: '{rom}',
              ),
            ),
          );
          continue;
        }
      }
      if (await _io.directoryExists(full)) {
        await _walk(full, byRom, emulator);
      }
    }
  }
}
