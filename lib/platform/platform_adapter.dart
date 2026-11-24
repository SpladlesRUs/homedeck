import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';

/// Result of a manual "add app" pick. Discovery is a separate, replaceable path.
class PickedLaunch {
  const PickedLaunch({
    required this.displayName,
    required this.target,
    this.kind = TileKind.native,
  });

  final String displayName;
  final LaunchTarget target;
  final TileKind kind;
}

/// Optional metadata from a future scanner (Steam library, ROM folders).
/// Milestone 1 does not populate this; [PlatformAdapter.discover] returns [].
class DiscoveredApp {
  const DiscoveredApp({
    required this.displayName,
    required this.target,
    this.kind = TileKind.native,
    this.iconHint,
  });

  final String displayName;
  final LaunchTarget target;
  final TileKind kind;
  final String? iconHint;
}

/// OS-specific discovery, icons, validation, and launch.
///
/// Shared UI must not import a concrete adapter. Inject this interface
/// (usually through [LibraryController]) instead.
abstract class PlatformAdapter {
  AppPlatform get platform;

  /// Installed-app scan. Milestone 1 returns an empty list (manual add only).
  Future<List<DiscoveredApp>> discover();

  /// Cache an icon under HomeDeck's data dir and return a relative [iconRef].
  Future<String?> resolveIcon({
    required LaunchTarget target,
    required IconCache cache,
    required String appId,
    required String displayName,
  });

  Future<LaunchOutcome> launch(LaunchTarget target);

  Future<LaunchFailure?> validateTarget(LaunchTarget target);

  Future<PickedLaunch?> pickLaunchTarget();

  /// Generic file pick used by the Add sheet (emulator, ROM, native exe).
  Future<String?> pickFile({
    required String label,
    required List<String> extensions,
  });
}
