import 'dart:io';

import 'package:path/path.dart' as p;

/// HomeDeck-owned locations under the platform support directory.
///
/// Every join/normalize goes through `package:path`. Callers must not
/// concatenate path fragments or hard-code drives, users, or separators.
class AppPaths {
  AppPaths(this.supportDirectory);

  final Directory supportDirectory;

  /// Prefer a Windows path context when the process is on Windows so
  /// `icons/<id>.png` (POSIX relative refs) join the same way Ally's AppData
  /// watcher expects (`…\HomeDeck\icons\<id>.png`).
  p.Context get _ctx =>
      Platform.isWindows ? p.windows : p.Context(style: p.Style.platform);

  String get supportRoot => supportDirectory.path;

  String get libraryFile => _ctx.join(supportRoot, 'library.json');

  String get iconsDirectory => _ctx.join(supportRoot, 'icons');

  /// Relative reference stored on [AppRecord.iconRef].
  ///
  /// Always POSIX separators so library.json is portable; [resolveOwned]
  /// turns this into a native path.
  String iconRelativeRef(String appId) {
    final safe = appId.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final id = safe.isEmpty ? 'icon' : safe;
    return p.posix.join('icons', '$id.png');
  }

  /// Resolve a HomeDeck-owned relative path. Rejects absolute inputs and
  /// anything that would escape [supportRoot].
  String resolveOwned(String relativeRef) {
    final normalized = _ctx.normalize(relativeRef.replaceAll('/', _ctx.separator));
    if (_ctx.isAbsolute(normalized) ||
        _ctx.split(normalized).contains('..')) {
      throw ArgumentError.value(
        relativeRef,
        'relativeRef',
        'HomeDeck-owned files must be referenced by a relative path',
      );
    }
    final root = _ctx.normalize(supportRoot);
    final joined = _ctx.normalize(_ctx.join(root, normalized));
    if (!_isUnderRoot(root, joined)) {
      throw ArgumentError.value(
        relativeRef,
        'relativeRef',
        'Path escapes the HomeDeck support directory',
      );
    }
    return joined;
  }

  bool _isUnderRoot(String root, String joined) {
    if (joined == root) {
      return true;
    }
    if (_ctx.isWithin(root, joined)) {
      return true;
    }
    // Windows: path_provider / Ally may disagree on slash style or casing.
    final rootLower = root.toLowerCase();
    final joinedLower = joined.toLowerCase();
    if (joinedLower == rootLower) {
      return true;
    }
    final prefix = rootLower.endsWith(_ctx.separator)
        ? rootLower
        : '$rootLower${_ctx.separator}';
    return joinedLower.startsWith(prefix);
  }

  File libraryJsonFile() => File(libraryFile);

  Directory iconsDir() => Directory(iconsDirectory);

  File iconFile(String relativeRef) => File(resolveOwned(relativeRef));
}
