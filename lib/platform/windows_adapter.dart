import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:homedeck/core/generated_icon.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_icon_extractor.dart';
import 'package:homedeck/platform/windows_io.dart';

typedef FilePickerFn = Future<String?> Function({
  required String label,
  required List<String> extensions,
});

/// Windows launch adapter.
///
/// Manual add: `.exe` / `.lnk`, store URIs (`steam://…`), or emulator + ROM.
/// Icons prefer a real PE / shortcut extract into [IconCache]; generated
/// initial tiles remain the fallback (see docs/DECISIONS.md).
class WindowsAdapter implements PlatformAdapter {
  WindowsAdapter({
    WindowsIo io = const DartWindowsIo(),
    FilePickerFn? filePicker,
    WindowsIconExtractor? iconExtractor,
  }) : _io = io,
       _filePicker = filePicker ?? _defaultPicker,
       _iconExtractor = iconExtractor ?? Win32IconExtractor();

  final WindowsIo _io;
  final FilePickerFn _filePicker;
  final WindowsIconExtractor _iconExtractor;

  static Future<String?> _defaultPicker({
    required String label,
    required List<String> extensions,
  }) async {
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
  Future<List<DiscoveredApp>> discover() async => const [];

  @override
  Future<String?> resolveIcon({
    required LaunchTarget target,
    required IconCache cache,
    required String appId,
    required String displayName,
  }) async {
    // Always land a generated PNG first. Ally f9b1d14 saw icons\ empty for
    // the whole run — a sync MethodChannel extract that blocks the Win32
    // message pump never returned, so writePng never ran. Generated art must
    // hit disk before any extract attempt.
    final generated = await generateInitialIcon(
      displayName: displayName,
      key: appId,
    );
    final ref = await cache.writePng(appId, generated);

    try {
      final extracted = await _tryExtractIcon(target).timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (extracted != null && extracted.isNotEmpty) {
        await cache.writePng(appId, extracted);
      }
    } catch (_) {
      // Keep the generated tile already on disk.
    }
    return ref;
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
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    if (WindowsPaths.isLaunchUri(path)) {
      return PickedLaunch(
        displayName: _uriDisplayName(path),
        target: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsUri,
          value: path.trim(),
        ),
      );
    }
    if (!WindowsPaths.isSupportedLaunchFile(path)) {
      return null;
    }
    final kind = WindowsPaths.isShortcut(path)
        ? LaunchTargetKind.windowsShortcut
        : LaunchTargetKind.windowsExecutable;
    return PickedLaunch(
      displayName: WindowsPaths.basenameWithoutExtension(path),
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: kind,
        value: path,
      ),
    );
  }

  String _uriDisplayName(String uri) {
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
