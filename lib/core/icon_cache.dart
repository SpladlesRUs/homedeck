import 'dart:async';
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

  /// Optional Win32 CreateFile write (set on Windows). Best-effort only —
  /// never awaited on the add critical path (Ally saw ready-marker via
  /// dart:io; tile writes must use that same join, not block on the channel).
  final Future<bool> Function(String path, Uint8List bytes)? _nativeWrite;

  static const readyProbeName = '_homedeck_ready.png';

  Future<Directory> ensureReady() async {
    final dir = paths.iconsDir();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    // Same join style as tile writes (see [_iconFileForId]).
    final probe = _fileInIconsDir(readyProbeName);
    if (!probe.existsSync() || probe.lengthSync() <= 0) {
      _durableWriteSync(probe, placeholderPng);
      _kickNativeWrite(probe.path, placeholderPng);
    }
    return dir;
  }

  /// Writes [bytes] to `icons/<appId>.png` beside [_homedeck_ready.png].
  ///
  /// Ally b630dc3: ready marker PASS but zero tile PNGs. Ready used
  /// `p.join(iconsDir.path, name)`; tiles used [AppPaths.iconFile] /
  /// `resolveOwned`, which can disagree with the live AppData path. Tile
  /// writes now use the identical icons-dir join as the ready marker.
  Future<String> writePng(String appId, Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'icon PNG bytes must be non-empty');
    }
    await ensureReady();
    final relative = paths.iconRelativeRef(appId);
    final file = _iconFileForId(appId);
    _durableWriteSync(file, bytes);
    _kickNativeWrite(file.path, bytes);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw FileSystemException(
        'icon PNG was not present after write',
        file.path,
      );
    }
    return relative;
  }

  /// Absolute file for a tile id — same directory join as the ready probe.
  File _iconFileForId(String appId) {
    final relative = paths.iconRelativeRef(appId);
    final name = p.posix.basename(relative);
    return _fileInIconsDir(name);
  }

  File _fileInIconsDir(String fileName) {
    // Intentionally mirrors ensureReady's probe path construction.
    return File(p.join(paths.iconsDirectory, fileName));
  }

  void _durableWriteSync(File file, Uint8List bytes) {
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
  }

  void _kickNativeWrite(String absolutePath, Uint8List bytes) {
    final native = _nativeWrite;
    if (native == null) {
      return;
    }
    // Fire-and-forget — awaiting MethodChannel after a successful dart:io
    // write stalled addRecord on Ally without helping the ready marker.
    unawaited(native(absolutePath, bytes).catchError((_) => false));
  }

  Future<Uint8List?> read(String relativeRef) async {
    final name = p.posix.basename(relativeRef);
    final file = _fileInIconsDir(name);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsBytesSync();
  }

  File? absoluteFile(String? relativeRef) {
    if (relativeRef == null || relativeRef.isEmpty) {
      return null;
    }
    final name = p.posix.basename(relativeRef);
    if (name.isEmpty || name == '.' || name == '..') {
      return null;
    }
    final file = _fileInIconsDir(name);
    if (!file.existsSync()) {
      return null;
    }
    return file;
  }
}
