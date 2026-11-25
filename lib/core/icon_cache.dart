import 'dart:io';
import 'dart:typed_data';

import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/placeholder_png.dart';
import 'package:path/path.dart' as p;

/// PNG tiles stored under the support directory and referenced relatively.
class IconCache {
  IconCache(this.paths, {Future<bool> Function(String path, Uint8List bytes)? nativeWrite})
    : _nativeWrite = nativeWrite;

  final AppPaths paths;

  /// Optional Win32 CreateFile write (set on Windows) so Ally sees bytes even
  /// if Dart `dart:io` flush is flaky on the handheld.
  final Future<bool> Function(String path, Uint8List bytes)? _nativeWrite;

  Future<Directory> ensureReady() async {
    final dir = paths.iconsDir();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    // Probe file so Ally's `icons\*.png` watcher can confirm the live AppData
    // path is writable before any add (empty icons\ alone was a false signal).
    final probe = File(p.join(dir.path, '_homedeck_ready.png'));
    if (!probe.existsSync() || probe.lengthSync() <= 0) {
      await _durableWrite(probe, placeholderPng);
    }
    return dir;
  }

  /// Writes [bytes] to `icons/<appId>.png` with durable sync IO (+ optional
  /// native CreateFile). Never depends on dart:ui.
  Future<String> writePng(String appId, Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'icon PNG bytes must be non-empty');
    }
    await ensureReady();
    final relative = paths.iconRelativeRef(appId);
    final file = paths.iconFile(relative);
    await _durableWrite(file, bytes);
    return relative;
  }

  Future<void> _durableWrite(File file, Uint8List bytes) async {
    file.parent.createSync(recursive: true);
    final payload = Uint8List.fromList(bytes);
    final temp = File('${file.path}.tmp');
    temp.writeAsBytesSync(payload, flush: true);
    try {
      temp.copySync(file.path);
    } on FileSystemException {
      file.writeAsBytesSync(payload, flush: true);
    }
    if (temp.existsSync()) {
      try {
        temp.deleteSync();
      } on FileSystemException {
        // Best-effort.
      }
    }
    file.writeAsBytesSync(payload, flush: true);

    final native = _nativeWrite;
    if (native != null) {
      try {
        await native(file.path, payload);
      } catch (_) {
        // Dart write is authoritative when native fails.
      }
    }

    final verify = File(file.path);
    if (!verify.existsSync() || verify.lengthSync() <= 0) {
      // Last resort: native-only rewrite.
      if (native != null) {
        final ok = await native(file.path, payload);
        if (ok && verify.existsSync() && verify.lengthSync() > 0) {
          return;
        }
      }
      throw FileSystemException(
        'icon PNG was not present after write',
        file.path,
      );
    }
  }

  Future<Uint8List?> read(String relativeRef) async {
    final file = paths.iconFile(relativeRef);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsBytesSync();
  }

  File? absoluteFile(String? relativeRef) {
    if (relativeRef == null || relativeRef.isEmpty) {
      return null;
    }
    final file = paths.iconFile(relativeRef);
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }
}
