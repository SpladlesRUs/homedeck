import 'dart:io';
import 'dart:typed_data';

import 'package:homedeck/core/app_paths.dart';

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

  /// Writes [bytes] to `icons/<appId>.png` with sync IO + flush.
  ///
  /// Ally M2 at 8715ce4 reported `icons\` empty after add while the UI still
  /// showed letter tiles (AppTile paints an initial face under a missing
  /// Image.file). Async `writeAsBytes` matched the library.json flake —
  /// sync flush matches [PreferencesRepository.save].
  Future<String> writePng(String appId, Uint8List bytes) async {
    await ensureReady();
    final relative = paths.iconRelativeRef(appId);
    final file = paths.iconFile(relative);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes, flush: true);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw FileSystemException(
        'icon PNG was not present after write',
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
