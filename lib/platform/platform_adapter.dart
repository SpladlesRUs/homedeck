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

/// Metadata from an installed-app scanner (Steam / Start Menu / ROM / Epic /
/// GOG / Ubisoft).
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

  /// Steam library scan on Windows; empty on other hosts.
  Future<List<DiscoveredApp>> discover();

  /// Start Menu Programs `.lnk` scan on Windows; empty on other hosts.
  Future<List<DiscoveredApp>> discoverStartMenu() async => const [];

  /// ROM-folder scan on Windows; empty on other hosts.
  ///
  /// [romRoot] is the Settings-persisted folder (ignored when
  /// `HOMEDECK_ROM_ROOT` is set). [emulator] is the `.exe` to attach when
  /// known; empty still imports ROM records for the user to complete later.
  Future<List<DiscoveredApp>> discoverRoms({
    String? romRoot,
    String? emulator,
  }) async =>
      const [];

  /// Epic Games Launcher `*.item` manifest scan on Windows; empty elsewhere.
  Future<List<DiscoveredApp>> discoverEpic() async => const [];

  /// GOG Galaxy `goggame-*.info` install scan on Windows; empty elsewhere.
  Future<List<DiscoveredApp>> discoverGog() async => const [];

  /// Ubisoft Connect / Uplay install scan on Windows; empty elsewhere.
  Future<List<DiscoveredApp>> discoverUbisoft() async => const [];

  /// EA App / Origin install scan on Windows; empty elsewhere.
  Future<List<DiscoveredApp>> discoverEa() async => const [];

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
