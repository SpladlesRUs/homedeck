import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/ea_library.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_adapter.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('EA installerdata.xml parsing', () {
    test('parseInstallerDataXml prefers origin URI and falls back to exe',
        () async {
      const withId = '''
<?xml version="1.0" encoding="UTF-8"?>
<DiPManifest>
  <gameTitles>
    <gameTitle locale="en_US">Bejeweled 3</gameTitle>
  </gameTitles>
  <contentIDs>
    <contentID>71715</contentID>
  </contentIDs>
</DiPManifest>
''';
      final ok = await parseInstallerDataXml(
        withId,
        installRoot: r'C:\EA Games\Bejeweled 3',
      );
      expect(ok, isNotNull);
      expect(ok!.displayName, 'Bejeweled 3');
      expect(ok.offerId, '71715');
      expect(ok.launchTarget.kind, LaunchTargetKind.windowsUri);
      expect(ok.launchTarget.value, 'origin://launchgame/71715');
      expect(
        SourceInference.storeFrom(ok.launchTarget.value),
        Storefront.ea,
      );

      const exeOnly = '''
<?xml version="1.0" encoding="UTF-8"?>
<DiPManifest>
  <gameTitles>
    <gameTitle locale="en_US">Standalone Title</gameTitle>
  </gameTitles>
  <filePath>Game.exe</filePath>
</DiPManifest>
''';
      final exe = await parseInstallerDataXml(
        exeOnly,
        installRoot: r'E:\EA Games\Standalone',
      );
      expect(exe, isNotNull);
      expect(exe!.launchTarget.kind, LaunchTargetKind.windowsExecutable);
      expect(
        exe.launchTarget.value,
        r'E:\EA Games\Standalone\Game.exe',
      );
      expect(
        SourceInference.storeFrom(exe.launchTarget.value),
        Storefront.ea,
      );
    });

    test('contentIdsFromInstallerXml and buildEaLaunchUri', () {
      const xml = '''
<contentIDs>
  <contentID>1002975</contentID>
  <contentID>1003943</contentID>
</contentIDs>
''';
      expect(contentIdsFromInstallerXml(xml), ['1002975', '1003943']);
      expect(
        buildEaLaunchUri(offerId: '71715'),
        'origin://launchgame/71715',
      );
      expect(buildEaLaunchUri(offerId: ''), isNull);
    });

    test('installEntryToManifest uses DisplayName and origin URI', () async {
      final m = await installEntryToManifest(
        const EaInstallEntry(
          offerId: '71715',
          installDir: r'C:\EA Games\Bejeweled 3',
          displayName: 'Bejeweled 3',
        ),
      );
      expect(m, isNotNull);
      expect(m!.displayName, 'Bejeweled 3');
      expect(m.launchTarget.value, 'origin://launchgame/71715');
      expect(SourceInference.storeFrom(m.launchTarget.value), Storefront.ea);
    });

    test('parseRegQuerySz extracts REG_SZ path', () {
      const stdout = r'''
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Origin Games\71715
    Install Dir    REG_SZ    C:\EA Games\Bejeweled 3
''';
      expect(
        EaLibraryScanner.parseRegQuerySz(stdout, 'Install Dir'),
        r'C:\EA Games\Bejeweled 3',
      );
    });
  });

  group('EaLibraryScanner', () {
    test('discovers installerdata under HOMEDECK_EA_ROOT-style fixture',
        () async {
      final games = win.join(r'C:\EA Games');
      final bejeweled = win.join(games, 'Bejeweled 3');
      final deadSpace = win.join(games, 'Dead Space');
      final bejeweledInstaller = win.join(bejeweled, '__Installer');
      final deadSpaceInstaller = win.join(deadSpace, '__Installer');
      final bejeweledXml = win.join(bejeweledInstaller, 'installerdata.xml');
      final deadSpaceXml = win.join(deadSpaceInstaller, 'installerdata.xml');

      final io = MemoryWindowsIo(
        directories: {
          games,
          bejeweled,
          deadSpace,
          bejeweledInstaller,
          deadSpaceInstaller,
        },
        directoryEntries: {
          games: ['Bejeweled 3', 'Dead Space', 'cache'],
          bejeweled: ['__Installer', 'Bejeweled3.exe'],
          deadSpace: ['__Installer'],
          bejeweledInstaller: ['installerdata.xml'],
          deadSpaceInstaller: ['installerdata.xml'],
        },
        textFiles: {
          bejeweledXml: '''
<?xml version="1.0" encoding="UTF-8"?>
<DiPManifest>
  <gameTitles>
    <gameTitle locale="en_US">Bejeweled 3</gameTitle>
  </gameTitles>
  <contentIDs>
    <contentID>71715</contentID>
  </contentIDs>
</DiPManifest>
''',
          deadSpaceXml: '''
<?xml version="1.0" encoding="UTF-8"?>
<DiPManifest>
  <gameTitles>
    <gameTitle locale="en_US">Dead Space</gameTitle>
  </gameTitles>
  <contentIDs>
    <contentID>1002975</contentID>
  </contentIDs>
</DiPManifest>
''',
        },
      );

      final scanner = EaLibraryScanner(
        io: io,
        candidateRoots: () => [games],
        registryInstalls: () async => const [],
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(found.map((e) => e.displayName).toList(), [
        'Bejeweled 3',
        'Dead Space',
      ]);
      expect(
        found.every((e) => e.target.kind == LaunchTargetKind.windowsUri),
        isTrue,
      );
      expect(
        found.every(
          (e) => SourceInference.storeFrom(e.target.value) == Storefront.ea,
        ),
        isTrue,
      );
    });

    test('discovers registry Origin Games entries as origin URIs', () async {
      final io = MemoryWindowsIo();
      final scanner = EaLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registryInstalls: () async => const [
          EaInstallEntry(
            offerId: '71715',
            installDir: r'C:\EA Games\Bejeweled 3',
            displayName: 'Bejeweled 3',
          ),
          EaInstallEntry(
            offerId: '1002975',
            installDir: r'D:\Games\Dead Space',
            displayName: 'Dead Space',
          ),
        ],
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(
        found.map((e) => e.target.value).toSet(),
        {
          'origin://launchgame/71715',
          'origin://launchgame/1002975',
        },
      );
    });

    test('WindowsAdapter.discoverEa uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = EaLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registryInstalls: () async => const [],
      );
      final adapter = WindowsAdapter(
        io: io,
        eaScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discoverEa(), isEmpty);
    });
  });

  group('LibraryController.importEa', () {
    test('adds new EA URIs and skips duplicates on re-import', () async {
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverEaResult: [
            DiscoveredApp(
              displayName: 'Bejeweled 3',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'origin://launchgame/71715',
              ),
            ),
            DiscoveredApp(
              displayName: 'Dead Space',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'origin://launchgame/1002975',
              ),
            ),
          ],
        ),
      );

      final first = await harness.controller.importEa();
      expect(first, 2);
      expect(harness.controller.apps, hasLength(2));
      expect(
        harness.controller.apps.every((a) => a.store == Storefront.ea),
        isTrue,
      );
      expect(
        harness.controller.home.contains(harness.controller.apps.first.id),
        isFalse,
      );

      final second = await harness.controller.importEa();
      expect(second, 0);
      expect(harness.controller.apps, hasLength(2));
    });
  });
}
