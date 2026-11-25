import 'dart:typed_data';

import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/platform/platform_adapter.dart';

/// 1x1 PNG so icon cache writes are valid files in tests.
final fakePng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class FakePlatformAdapter implements PlatformAdapter {
  FakePlatformAdapter({
    this.pick,
    this.validation,
    this.launchResult,
    this.discoverResult = const [],
    this.discoverStartMenuResult = const [],
    this.discoverRomsResult = const [],
  });

  PickedLaunch? pick;
  LaunchFailure? validation;
  LaunchOutcome? launchResult;
  List<DiscoveredApp> discoverResult;
  List<DiscoveredApp> discoverStartMenuResult;
  List<DiscoveredApp> discoverRomsResult;
  String? lastRomRoot;
  String? lastRomEmulator;
  final fileQueue = <String>[];
  int launchCount = 0;
  int validateCount = 0;
  int pickCount = 0;
  final launched = <LaunchTarget>[];

  @override
  AppPlatform get platform => AppPlatform.windows;

  @override
  Future<List<DiscoveredApp>> discover() async => discoverResult;

  @override
  Future<List<DiscoveredApp>> discoverStartMenu() async =>
      discoverStartMenuResult;

  @override
  Future<List<DiscoveredApp>> discoverRoms({
    String? romRoot,
    String? emulator,
  }) async {
    lastRomRoot = romRoot;
    lastRomEmulator = emulator;
    return discoverRomsResult;
  }

  @override
  Future<LaunchOutcome> launch(LaunchTarget target) async {
    launchCount++;
    launched.add(target);
    final blocked = await validateTarget(target);
    if (blocked != null) {
      return blocked;
    }
    return launchResult ?? const LaunchSuccess();
  }

  @override
  Future<PickedLaunch?> pickLaunchTarget() async {
    pickCount++;
    return pick;
  }

  @override
  Future<String?> pickFile({
    required String label,
    required List<String> extensions,
  }) async {
    pickCount++;
    if (fileQueue.isNotEmpty) {
      return fileQueue.removeAt(0);
    }
    return pick?.target.value;
  }

  @override
  Future<String?> resolveIcon({
    required LaunchTarget target,
    required IconCache cache,
    required String appId,
    required String displayName,
  }) async {
    // Sync write so widget tests in the fake-async zone can finish addRecord.
    final relative = cache.paths.iconRelativeRef(appId);
    final file = cache.paths.iconFile(relative);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(fakePng, flush: true);
    return relative;
  }

  @override
  Future<LaunchFailure?> validateTarget(LaunchTarget target) async {
    validateCount++;
    return validation;
  }
}
