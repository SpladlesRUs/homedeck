import 'package:path/path.dart' as p;

/// Windows path helpers that never hard-code a drive, user, or separator.
///
/// Uses a Windows [p.Context] so the same logic can be unit-tested on Linux.
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
  /// Does not treat POSIX paths as volumes, so the shared UI can run on Linux.
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
}
