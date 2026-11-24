import 'dart:io';

import 'package:path/path.dart' as p;

/// HomeDeck-owned locations under the platform support directory.
///
/// Every join/normalize goes through `package:path`. Callers must not
/// concatenate path fragments or hard-code drives, users, or separators.
class AppPaths {
  AppPaths(this.supportDirectory);

  final Directory supportDirectory;

  String get supportRoot => supportDirectory.path;

  String get libraryFile => p.join(supportRoot, 'library.json');

  String get iconsDirectory => p.join(supportRoot, 'icons');

  /// Relative reference stored on [AppRecord.iconRef].
  String iconRelativeRef(String appId) => p.join('icons', '$appId.png');

  /// Resolve a HomeDeck-owned relative path. Rejects absolute inputs and
  /// anything that would escape [supportRoot].
  String resolveOwned(String relativeRef) {
    final normalized = p.normalize(relativeRef);
    if (p.isAbsolute(normalized) || p.split(normalized).contains('..')) {
      throw ArgumentError.value(
        relativeRef,
        'relativeRef',
        'HomeDeck-owned files must be referenced by a relative path',
      );
    }
    final joined = p.normalize(p.join(supportRoot, normalized));
    if (joined != p.normalize(supportRoot) && !p.isWithin(supportRoot, joined)) {
      throw ArgumentError.value(
        relativeRef,
        'relativeRef',
        'Path escapes the HomeDeck support directory',
      );
    }
    return joined;
  }

  File libraryJsonFile() => File(libraryFile);

  Directory iconsDir() => Directory(iconsDirectory);

  File iconFile(String relativeRef) => File(resolveOwned(relativeRef));
}
