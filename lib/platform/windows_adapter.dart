import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:homedeck/core/generated_icon.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';

typedef FilePickerFn = Future<String?> Function();

/// Windows launch adapter (milestone 1).
///
/// Manual add only: the user picks a `.exe` or `.lnk`. Icons fall back to a
/// generated colored initial tile because PE resource extraction is not
/// implemented (see docs/DECISIONS.md).
class WindowsAdapter implements PlatformAdapter {
  WindowsAdapter({
    WindowsIo io = const DartWindowsIo(),
    FilePickerFn? filePicker,
  }) : _io = io,
       _filePicker = filePicker ?? _defaultPicker;

  final WindowsIo _io;
  final FilePickerFn _filePicker;

  static const _windowsTypeGroup = XTypeGroup(
    label: 'Windows apps',
    extensions: ['exe', 'lnk'],
  );

  static Future<String?> _defaultPicker() async {
    final file = await openFile(
      acceptedTypeGroups: const [_windowsTypeGroup],
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
    // Milestone 1 does not parse PE resources or .lnk icon paths.
    final bytes = await generateInitialIcon(
      displayName: displayName,
      key: appId,
    );
    return cache.writePng(appId, bytes);
  }

  @override
  Future<LaunchFailure?> validateTarget(LaunchTarget target) async {
    if (target.platform != AppPlatform.windows) {
      return LaunchFailure.launchFailed(
        targetValue: target.value,
        detail: 'This tile has no Windows launch target.',
      );
    }
    final raw = target.value.trim();
    if (raw.isEmpty) {
      return LaunchFailure.missingFile(targetValue: raw);
    }

    if (WindowsPaths.looksLikeVolumePath(raw)) {
      final root = WindowsPaths.rootPrefix(raw);
      try {
        final ready = await _io.volumeReady(root);
        if (!ready) {
          return LaunchFailure.removedDrive(targetValue: raw);
        }
      } on FileSystemException catch (error) {
        return _mapIoError(error, raw);
      }
    }

    try {
      final exists = await _io.fileExists(raw);
      if (!exists) {
        return LaunchFailure.missingFile(targetValue: raw);
      }
      await _io.checkReadable(raw);
    } on FileSystemException catch (error) {
      return _mapIoError(error, raw);
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
      await _io.startDetached(
        executable: target.value,
        arguments: target.arguments,
        shortcut: target.kind == LaunchTargetKind.windowsShortcut ||
            WindowsPaths.isShortcut(target.value),
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
  Future<PickedLaunch?> pickLaunchTarget() async {
    final path = await _filePicker();
    if (path == null || path.trim().isEmpty) {
      return null;
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
