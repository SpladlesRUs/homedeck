import 'package:path/path.dart' as p;

/// Windows path helpers that never hard-code a drive, user, or separator.
///
/// Uses a Windows [p.Context] so the same logic can be unit-tested on any host.
class WindowsPaths {
  WindowsPaths._();

  static final p.Context context = p.Context(style: p.Style.windows);

  static String normalize(String raw) => context.normalize(raw);

  static String basename(String raw) => context.basename(raw);

  static String basenameWithoutExtension(String raw) =>
      context.basenameWithoutExtension(raw);

  static String extension(String raw) => context.extension(raw).toLowerCase();

  /// Drive or UNC root, for example `D:\` or `\\server\share\`. Empty when
  /// [raw] is not a Windows absolute path.
  static String rootPrefix(String raw) => context.rootPrefix(normalize(raw));

  static bool isAbsolute(String raw) => context.isAbsolute(raw);

  static final _driveRoot = RegExp(r'^[A-Za-z]:[\\/]');

  /// True for a Windows drive (`X:\...`) or UNC share (`\\host\share\...`).
  /// POSIX paths are not treated as volumes.
  static bool looksLikeVolumePath(String raw) {
    final normalized = normalize(raw);
    if (_driveRoot.hasMatch(normalized)) {
      return true;
    }
    return normalized.startsWith(r'\\') && normalized.length > 2;
  }

  static bool isShortcut(String raw) => extension(raw) == '.lnk';

  static bool isExecutable(String raw) => extension(raw) == '.exe';

  static bool isSupportedLaunchFile(String raw) =>
      isShortcut(raw) || isExecutable(raw);

  static final _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+\-.]*:');

  /// Store / protocol URIs such as `steam://rungameid/440`. File paths and
  /// http(s) URLs are not treated as launch URIs.
  static bool isLaunchUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (looksLikeVolumePath(trimmed) || isAbsolute(trimmed)) {
      return false;
    }
    final match = _scheme.firstMatch(trimmed);
    if (match == null) {
      return false;
    }
    final scheme = match.group(0)!.replaceAll(':', '').toLowerCase();
    if (scheme == 'file' || scheme == 'http' || scheme == 'https') {
      return false;
    }
    return true;
  }
}
