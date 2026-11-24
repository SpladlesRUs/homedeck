import 'dart:io';
import 'dart:typed_data';

import 'package:homedeck/core/app_paths.dart';

/// PNG tiles stored under the support directory and referenced relatively.
class IconCache {
  IconCache(this.paths);

  final AppPaths paths;

  Future<Directory> ensureReady() async {
    final dir = paths.iconsDir();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> writePng(String appId, Uint8List bytes) async {
    await ensureReady();
    final relative = paths.iconRelativeRef(appId);
    final file = paths.iconFile(relative);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return relative;
  }

  Future<Uint8List?> read(String relativeRef) async {
    final file = paths.iconFile(relativeRef);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  File? absoluteFile(String? relativeRef) {
    if (relativeRef == null || relativeRef.isEmpty) {
      return null;
    }
    return paths.iconFile(relativeRef);
  }
}
