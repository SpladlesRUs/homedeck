import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/ubisoft_library.dart';
import 'package:homedeck/platform/windows_adapter.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('Ubisoft ubisoftgame-*.info parsing', () {
    test('parseUbisoftInfo prefers uplay URI and falls back to exe', () async {
      const withId = '''
{
  "gameId": "1234",
  "name": "Far Cry 5",
  "exe": "bin\\\\FarCry5.exe"
}
''';
      final ok = await parseUbisoftInfo(
        withId,
        installRoot: r'C:\Ubisoft Games\Far Cry 5',
      );
      expect(ok, isNotNull);
      expect(ok!.displayName, 'Far Cry 5');
      expect(ok.gameId, '1234');
      expect(ok.launchTarget.kind, LaunchTargetKind.windowsUri);
      expect(ok.launchTarget.value, 'uplay://launch/1234/0');
      expect(
        SourceInference.storeFrom(ok.launchTarget.value),
        Storefront.ubisoft,
      );

      const exeOnly = '''
{
  "name": "Standalone Title",
  "exe": "Game.exe"
}
''';
      final exe = await parseUbisoftInfo(
        exeOnly,
        installRoot: r'E:\Ubisoft Games\Standalone',
      );
      expect(exe, isNotNull);
      expect(exe!.launchTarget.kind, LaunchTargetKind.windowsExecutable);
      expect(
        exe.launchTarget.value,
        r'E:\Ubisoft Games\Standalone\Game.exe',
      );
      expect(
        SourceInference.storeFrom(exe.launchTarget.value),
        Storefront.ubisoft,
      );
    });

    test('gameIdFromInfoFileName and buildUbisoftLaunchUri', () {
      expect(gameIdFromInfoFileName('ubisoftgame-565.info'), '565');
      expect(gameIdFromInfoFileName('readme.txt'), isNull);
      expect(
        buildUbisoftLaunchUri(gameId: '273'),
        'uplay://launch/273/0',
      );
      expect(buildUbisoftLaunchUri(gameId: ''), isNull);
    });

    test('installEntryToManifest uses DisplayName and uplay URI', () {
      final m = installEntryToManifest(
        const UbisoftInstallEntry(
          gameId: '1234',
          installDir: r'C:\Ubisoft Games\Far Cry 5',
          displayName: 'Far Cry 5',
        ),
      );
      expect(m, isNotNull);
      expect(m!.displayName, 'Far Cry 5');
      expect(m.launchTarget.value, 'uplay://launch/1234/0');
      expect(SourceInference.storeFrom(m.launchTarget.value), Storefront.ubisoft);
    });

    test('parseRegQuerySz extracts REG_SZ path', () {
      const stdout = r'''
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Ubisoft\Launcher\Installs\1234
    InstallDir    REG_SZ    C:\Ubisoft Games\Far Cry 5
''';
      expect(
        UbisoftLibraryScanner.parseRegQuerySz(stdout, 'InstallDir'),
        r'C:\Ubisoft Games\Far Cry 5',
      );
    });
  });

  group('UbisoftLibraryScanner', () {
    test('discovers ubisoftgame info under HOMEDECK_UBISOFT_ROOT-style fixture',
        () async {
      final games = win.join(r'C:\Ubisoft Games');
      final farCry = win.join(games, 'Far Cry 5');
      final odyssey = win.join(games, 'Assassins Creed Odyssey');
      final farCryInfo = win.join(farCry, 'ubisoftgame-1234.info');
      final odysseyInfo = win.join(odyssey, 'ubisoftgame-911.info');

      final io = MemoryWindowsIo(
        directories: {games, farCry, odyssey},
        directoryEntries: {
          games: ['Far Cry 5', 'Assassins Creed Odyssey', 'cache'],
          farCry: ['ubisoftgame-1234.info', 'bin'],
          odyssey: ['ubisoftgame-911.info'],
        },
        textFiles: {
          farCryInfo: '''
{
  "gameId": "1234",
  "name": "Far Cry 5",
  "exe": "bin\\\\FarCry5.exe"
}
''',
          odysseyInfo: '''
{
  "gameId": "911",
  "name": "Assassin's Creed Odyssey",
  "exe": "ACOdyssey.exe"
}
''',
        },
      );

      final scanner = UbisoftLibraryScanner(
        io: io,
        candidateRoots: () => [games],
        registryInstalls: () async => const [],
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(found.map((e) => e.displayName).toList(), [
        "Assassin's Creed Odyssey",
        'Far Cry 5',
      ]);
      expect(
        found.every((e) => e.target.kind == LaunchTargetKind.windowsUri),
        isTrue,
      );
      expect(
        found.every(
          (e) =>
              SourceInference.storeFrom(e.target.value) == Storefront.ubisoft,
        ),
        isTrue,
      );
    });

    test('discovers registry Installs entries as uplay URIs', () async {
      final io = MemoryWindowsIo();
      final scanner = UbisoftLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registryInstalls: () async => const [
          UbisoftInstallEntry(
            gameId: '1234',
            installDir: r'C:\Ubisoft Games\Far Cry 5',
            displayName: 'Far Cry 5',
          ),
          UbisoftInstallEntry(
            gameId: '911',
            installDir: r'D:\Games\AC Odyssey',
            displayName: "Assassin's Creed Odyssey",
          ),
        ],
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(
        found.map((e) => e.target.value).toSet(),
        {'uplay://launch/1234/0', 'uplay://launch/911/0'},
      );
    });

    test('WindowsAdapter.discoverUbisoft uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = UbisoftLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registryInstalls: () async => const [],
      );
      final adapter = WindowsAdapter(
        io: io,
        ubisoftScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discoverUbisoft(), isEmpty);
    });
  });

  group('LibraryController.importUbisoft', () {
    test('adds new Ubisoft URIs and skips duplicates on re-import', () async {
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverUbisoftResult: [
            DiscoveredApp(
              displayName: 'Far Cry 5',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'uplay://launch/1234/0',
              ),
            ),
            DiscoveredApp(
              displayName: "Assassin's Creed Odyssey",
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'uplay://launch/911/0',
              ),
            ),
          ],
        ),
      );

      final first = await harness.controller.importUbisoft();
      expect(first, 2);
      expect(harness.controller.apps, hasLength(2));
      expect(
        harness.controller.apps.every((a) => a.store == Storefront.ubisoft),
        isTrue,
      );
      expect(
        harness.controller.home.contains(harness.controller.apps.first.id),
        isFalse,
      );

      final second = await harness.controller.importUbisoft();
      expect(second, 0);
      expect(harness.controller.apps, hasLength(2));
    });
  });
}
