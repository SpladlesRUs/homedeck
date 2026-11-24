import 'dart:io';

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
    // Prefer ShellExecuteW on Windows — Ally Phase2 Enter after add never
    // spawned notepad when we only used detached `cmd /c start`.
    if (Platform.isWindows &&
        WindowsShell.open(executable, arguments: arguments)) {
      return;
    }
    if (shortcut || Platform.isWindows) {
      // `start` treats the first quoted token as a window title. The empty
      // string occupies that slot so [executable] is the launch target.
      // Arguments stay a list — never concatenated — so spaces and Unicode
      // in the path are preserved.
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
