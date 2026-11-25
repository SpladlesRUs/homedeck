import 'dart:io';

import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/windows_native_bridge.dart';
import 'package:homedeck/platform/windows_shell.dart';

/// Filesystem and process operations used by [WindowsAdapter].
///
/// Injected so path handling (spaces, Unicode, missing files, removed
/// volumes) can be tested without a real Windows box.
abstract class WindowsIo {
  Future<bool> fileExists(String path);

  Future<bool> volumeReady(String rootPrefix);

  /// Throws [FileSystemException] when the file cannot be opened for read.
  Future<void> checkReadable(String path);

  Future<void> startDetached({
    required String executable,
    required List<String> arguments,
    required bool shortcut,
  });
}

class DartWindowsIo implements WindowsIo {
  const DartWindowsIo();

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<bool> volumeReady(String rootPrefix) => Directory(rootPrefix).exists();

  @override
  Future<void> checkReadable(String path) async {
    final raf = await File(path).open();
    await raf.close();
  }

  @override
  Future<void> startDetached({
    required String executable,
    required List<String> arguments,
    required bool shortcut,
  }) async {
    // 1) Runner MethodChannel ShellExecuteW — Ally 2417533 Dart FFI path
    // never spawned notepad after Enter.
    if (Platform.isWindows &&
        await WindowsNativeBridge.launch(
          executable,
          arguments: arguments,
        )) {
      return;
    }
    // 2) Dart FFI ShellExecuteW (best-effort when channel missing).
    if (Platform.isWindows &&
        WindowsShell.open(executable, arguments: arguments)) {
      return;
    }
    // 3) Direct CreateProcess for .exe (not .lnk / URI).
    final isLnk = executable.toLowerCase().endsWith('.lnk');
    final isUri = WindowsPaths.isLaunchUri(executable);
    if (Platform.isWindows && !isLnk && !isUri) {
      try {
        await Process.start(
          executable,
          arguments,
          mode: ProcessStartMode.detached,
        );
        return;
      } catch (_) {
        // Fall through to cmd start.
      }
    }
    if (shortcut || Platform.isWindows) {
      // `start` treats the first quoted token as a window title. The empty
      // string occupies that slot so [executable] is the launch target.
      await Process.start(
        'cmd',
        ['/c', 'start', '', executable, ...arguments],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
    );
  }
}
