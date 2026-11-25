import 'dart:io';

import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:homedeck/platform/windows_native_bridge.dart';
import 'package:path/path.dart' as p;

/// Resolved `.lnk` launch fields (IShellLink GetPath / GetArguments).
class ResolvedShortcut {
  const ResolvedShortcut({
    this.targetPath,
    this.arguments = const [],
  });

  /// Absolute path or protocol URI from the shortcut, when available.
  final String? targetPath;
  final List<String> arguments;
}

typedef ShortcutResolver = Future<ResolvedShortcut?> Function(String lnkPath);

/// Scans Windows Start Menu Programs folders for `.lnk` shortcuts.
///
/// Default roots are `%APPDATA%\Microsoft\Windows\Start Menu\Programs` and
/// `%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs`. Optional
/// `HOMEDECK_START_MENU_ROOT` (Ally / CI fixture) replaces those roots.
///
/// Launch targets prefer a resolved `.exe` ([LaunchTargetKind.windowsExecutable])
/// or URI ([LaunchTargetKind.windowsUri]); otherwise the `.lnk` itself is kept
/// as [LaunchTargetKind.windowsShortcut] so ShellExecute still works.
class StartMenuScanner {
  StartMenuScanner({
    required WindowsIo io,
    List<String> Function()? programRoots,
    ShortcutResolver? resolveShortcut,
    p.Context? pathContext,
  }) : _io = io,
       _programRoots = programRoots ?? defaultProgramRoots,
       _resolveShortcut = resolveShortcut ?? defaultResolveShortcut,
       _path = pathContext ?? WindowsPaths.context;

  final WindowsIo _io;
  final List<String> Function() _programRoots;
  final ShortcutResolver _resolveShortcut;
  final p.Context _path;

  /// User + all-users Start Menu Programs paths from the environment.
  ///
  /// When `HOMEDECK_START_MENU_ROOT` is set, that single fixture root is used
  /// (Ally / CI). Paths are never hard-coded with a drive letter.
  static List<String> defaultProgramRoots() {
    final env = Platform.environment;
    final path = WindowsPaths.context;
    final forced = env['HOMEDECK_START_MENU_ROOT']?.trim();
    if (forced != null && forced.isNotEmpty) {
      return [WindowsPaths.normalize(forced)];
    }
    final out = <String>[];
    final seen = <String>{};

    void addProgramsUnder(String? base) {
      if (base == null || base.trim().isEmpty) {
        return;
      }
      final root = path.join(
        base,
        'Microsoft',
        'Windows',
        'Start Menu',
        'Programs',
      );
      final key = WindowsPaths.normalize(root).toLowerCase();
      if (seen.add(key)) {
        out.add(WindowsPaths.normalize(root));
      }
    }

    addProgramsUnder(env['APPDATA']);
    addProgramsUnder(env['PROGRAMDATA']);
    addProgramsUnder(env['ALLUSERSPROFILE']);
    return out;
  }

  /// Resolves a `.lnk` via the Windows runner MethodChannel when available.
  static Future<ResolvedShortcut?> defaultResolveShortcut(String lnkPath) async {
    final map = await WindowsNativeBridge.resolveShortcut(lnkPath);
    if (map == null) {
      return null;
    }
    final target = (map['target'] as String?)?.trim();
    final argsRaw = map['arguments'];
    final arguments = <String>[];
    if (argsRaw is String && argsRaw.trim().isNotEmpty) {
      arguments.addAll(_tokenizeArgs(argsRaw.trim()));
    } else if (argsRaw is List) {
      for (final entry in argsRaw) {
        final text = '$entry'.trim();
        if (text.isNotEmpty) {
          arguments.add(text);
        }
      }
    }
    if ((target == null || target.isEmpty) && arguments.isEmpty) {
      return null;
    }
    return ResolvedShortcut(
      targetPath: (target == null || target.isEmpty) ? null : target,
      arguments: List<String>.unmodifiable(arguments),
    );
  }

  static List<String> _tokenizeArgs(String input) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == '"') {
        inQuote = !inQuote;
        continue;
      }
      if (!inQuote && (ch == ' ' || ch == '\t')) {
        if (buf.isNotEmpty) {
          out.add(buf.toString());
          buf.clear();
        }
        continue;
      }
      buf.write(ch);
    }
    if (buf.isNotEmpty) {
      out.add(buf.toString());
    }
    return out;
  }

  Future<List<DiscoveredApp>> discover() async {
    final roots = _programRoots();
    if (roots.isEmpty) {
      return const [];
    }

    final byTarget = <String, DiscoveredApp>{};
    for (final root in roots) {
      if (!await _io.directoryExists(root)) {
        continue;
      }
      await _walkPrograms(root, byTarget);
    }

    final list = byTarget.values.toList(growable: false)
      ..sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
    return list;
  }

  Future<void> _walkPrograms(
    String directory,
    Map<String, DiscoveredApp> byTarget,
  ) async {
    final names = await _io.listDirectory(directory);
    for (final name in names) {
      if (name == '.' || name == '..') {
        continue;
      }
      final full = _path.join(directory, name);
      final lower = name.toLowerCase();
      if (lower.endsWith('.lnk')) {
        if (!await _io.fileExists(full)) {
          continue;
        }
        final app = await _discoveredFromLnk(full, name);
        if (app == null) {
          continue;
        }
        final key = app.target.value.trim().toLowerCase();
        if (key.isEmpty) {
          continue;
        }
        byTarget.putIfAbsent(key, () => app);
        continue;
      }
      if (await _io.directoryExists(full)) {
        await _walkPrograms(full, byTarget);
      }
    }
  }

  Future<DiscoveredApp?> _discoveredFromLnk(
    String lnkPath,
    String fileName,
  ) async {
    final displayName = WindowsPaths.basenameWithoutExtension(fileName).trim();
    if (displayName.isEmpty) {
      return null;
    }
    final normalizedLnk = WindowsPaths.normalize(lnkPath);
    ResolvedShortcut? resolved;
    try {
      resolved = await _resolveShortcut(normalizedLnk);
    } catch (_) {
      resolved = null;
    }

    final targetRaw = resolved?.targetPath?.trim();
    if (targetRaw != null && targetRaw.isNotEmpty) {
      if (WindowsPaths.isLaunchUri(targetRaw)) {
        return DiscoveredApp(
          displayName: displayName,
          kind: TileKind.native,
          target: LaunchTarget(
            platform: AppPlatform.windows,
            kind: LaunchTargetKind.windowsUri,
            value: targetRaw,
          ),
        );
      }
      final normalizedTarget = WindowsPaths.normalize(
        targetRaw.replaceAll('/', r'\'),
      );
      if (WindowsPaths.isExecutable(normalizedTarget)) {
        // Skip broken Start Menu entries whose .exe was uninstalled.
        try {
          if (!await _io.fileExists(normalizedTarget)) {
            return null;
          }
        } catch (_) {
          return null;
        }
        return DiscoveredApp(
          displayName: displayName,
          kind: TileKind.native,
          target: LaunchTarget(
            platform: AppPlatform.windows,
            kind: LaunchTargetKind.windowsExecutable,
            value: normalizedTarget,
            arguments: resolved?.arguments ?? const [],
          ),
        );
      }
      if (WindowsPaths.isShortcut(normalizedTarget)) {
        return DiscoveredApp(
          displayName: displayName,
          kind: TileKind.native,
          target: LaunchTarget(
            platform: AppPlatform.windows,
            kind: LaunchTargetKind.windowsShortcut,
            value: normalizedTarget,
          ),
        );
      }
    }

    // Unresolved / non-exe targets (UWP, scripts, folders-as-link): keep the
    // .lnk so ShellExecute still opens whatever the shortcut points at.
    return DiscoveredApp(
      displayName: displayName,
      kind: TileKind.native,
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsShortcut,
        value: normalizedLnk,
      ),
    );
  }
}
