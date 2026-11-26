import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/gog_library.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_adapter.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('GOG goggame-*.info parsing', () {
    test('parseGogInfo prefers openGameView URI and falls back to exe', () {
      const withId = '''
{
  "gameId": "1207659026",
  "name": "The Witcher 3",
  "playTasks": [
    {
      "isPrimary": true,
      "path": "bin\\\\x64\\\\witcher3.exe",
      "type": "FileTask"
    }
  ]
}
''';
      final ok = parseGogInfo(
        withId,
        installRoot: r'C:\GOG Games\The Witcher 3',
      );
      expect(ok, isNotNull);
      expect(ok!.displayName, 'The Witcher 3');
      expect(ok.gameId, '1207659026');
      expect(ok.launchTarget.kind, LaunchTargetKind.windowsUri);
      expect(
        ok.launchTarget.value,
        'goggalaxy://openGameView/1207659026',
      );
      expect(SourceInference.storeFrom(ok.launchTarget.value), Storefront.gog);

      const exeOnly = '''
{
  "name": "Standalone Title",
  "playTasks": [
    {
      "isPrimary": true,
      "path": "Game.exe",
      "type": "FileTask"
    }
  ]
}
''';
      final exe = parseGogInfo(
        exeOnly,
        installRoot: r'E:\GOG Games\Standalone',
      );
      expect(exe, isNotNull);
      expect(exe!.launchTarget.kind, LaunchTargetKind.windowsExecutable);
      expect(
        exe.launchTarget.value,
        r'E:\GOG Games\Standalone\Game.exe',
      );
      expect(
        SourceInference.storeFrom(exe.launchTarget.value),
        Storefront.gog,
      );
    });

    test('gameIdFromInfoFileName and buildGogLaunchUri', () {
      expect(gameIdFromInfoFileName('goggame-1444826419.info'), '1444826419');
      expect(gameIdFromInfoFileName('readme.txt'), isNull);
      expect(
        buildGogLaunchUri(gameId: '1971477531'),
        'goggalaxy://openGameView/1971477531',
      );
      expect(buildGogLaunchUri(gameId: ''), isNull);
    });

    test('parseRegQuerySz extracts REG_SZ path', () {
      const stdout = r'''
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\GOG.com\GalaxyClient\paths
    client    REG_SZ    C:\Program Files (x86)\GOG Galaxy
''';
      expect(
        GogLibraryScanner.parseRegQuerySz(stdout, 'client'),
        r'C:\Program Files (x86)\GOG Galaxy',
      );
    });
  });

  group('GogLibraryScanner', () {
    test('discovers goggame info under HOMEDECK_GOG_ROOT-style fixture',
        () async {
      final games = win.join(r'C:\GOG Games');
      final witcher = win.join(games, 'The Witcher 3');
      final hike = win.join(games, 'A Short Hike');
      final witcherInfo = win.join(witcher, 'goggame-1207659026.info');
      final hikeInfo = win.join(hike, 'goggame-1453375253.info');

      final io = MemoryWindowsIo(
        directories: {games, witcher, hike},
        directoryEntries: {
          games: ['The Witcher 3', 'A Short Hike', '_CommonRedist'],
          witcher: ['goggame-1207659026.info', 'bin'],
          hike: ['goggame-1453375253.info'],
        },
        textFiles: {
          witcherInfo: '''
{
  "gameId": "1207659026",
  "name": "The Witcher 3",
  "playTasks": [
    { "isPrimary": true, "path": "bin\\\\x64\\\\witcher3.exe", "type": "FileTask" }
  ]
}
''',
          hikeInfo: '''
{
  "gameId": "1453375253",
  "name": "A Short Hike",
  "playTasks": [
    { "isPrimary": true, "path": "AShortHike.exe", "type": "FileTask" }
  ]
}
''',
        },
      );

      final scanner = GogLibraryScanner(
        io: io,
        candidateRoots: () => [games],
        registryInstallRoots: () async => const [],
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(found.map((e) => e.displayName).toList(), [
        'A Short Hike',
        'The Witcher 3',
      ]);
      expect(
        found.every((e) => e.target.kind == LaunchTargetKind.windowsUri),
        isTrue,
      );
      expect(
        found.every(
          (e) => SourceInference.storeFrom(e.target.value) == Storefront.gog,
        ),
        isTrue,
      );
    });

    test('WindowsAdapter.discoverGog uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = GogLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registryInstallRoots: () async => const [],
      );
      final adapter = WindowsAdapter(
        io: io,
        gogScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discoverGog(), isEmpty);
    });
  });

  group('LibraryController.importGog', () {
    test('adds new GOG URIs and skips duplicates on re-import', () async {
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverGogResult: [
            DiscoveredApp(
              displayName: 'The Witcher 3',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'goggalaxy://openGameView/1207659026',
              ),
            ),
            DiscoveredApp(
              displayName: 'A Short Hike',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'goggalaxy://openGameView/1453375253',
              ),
            ),
          ],
        ),
      );

      final first = await harness.controller.importGog();
      expect(first, 2);
      expect(harness.controller.apps, hasLength(2));
      expect(
        harness.controller.apps.every((a) => a.store == Storefront.gog),
        isTrue,
      );
      expect(
        harness.controller.home.contains(harness.controller.apps.first.id),
        isFalse,
      );

      final second = await harness.controller.importGog();
      expect(second, 0);
      expect(harness.controller.apps, hasLength(2));
    });
  });
}
