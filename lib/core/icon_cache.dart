import 'dart:io';
import 'dart:typed_data';

import 'package:homedeck/core/app_paths.dart';
import 'package:path/path.dart' as p;

/// PNG tiles stored under the support directory and referenced relatively.
class IconCache {
  IconCache(this.paths);

  final AppPaths paths;

  Future<Directory> ensureReady() async {
    final dir = paths.iconsDir();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Writes [bytes] to `icons/<appId>.png` with the same durable sync pattern
  /// as [PreferencesRepository.save] (temp + copy + authoritative overwrite).
  ///
  /// Ally M2 re-smoke at f9b1d14 still saw zero PNGs under
  /// `%AppData%\Horton Press\HomeDeck\icons` for the whole run — even the
  /// generated-tile fallback. A hung sync MethodChannel extract before any
  /// write left the folder empty while AppTile painted letter faces.
  Future<String> writePng(String appId, Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'icon PNG bytes must be non-empty');
    }
    await ensureReady();
    final relative = paths.iconRelativeRef(appId);
    final file = paths.iconFile(relative);
    file.parent.createSync(recursive: true);

    final payload = Uint8List.fromList(bytes);
    final temp = File(p.join(file.parent.path, '$appId.png.tmp'));
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
        // Best-effort; [file] is what Ally checks.
      }
    }
    // Final authoritative write — same as library.json on Ally.
    file.writeAsBytesSync(payload, flush: true);

    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw FileSystemException(
        'icon PNG was not present after write',
        file.path,
      );
    }
    // Re-open by absolute path to catch path-resolution mismatches.
    final verify = File(file.path);
    if (!verify.existsSync() || verify.lengthSync() != payload.length) {
      throw FileSystemException(
        'icon PNG failed verification after write',
        file.path,
      );
    }
    return relative;
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
