import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/epic_library.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_adapter.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('Epic .item parsing', () {
    test('parseItemManifest prefers catalog URI and skips incomplete', () {
      const installed = '''
{
  "bIsIncompleteInstall": false,
  "AppName": "Turaco",
  "DisplayName": "Nuclear Throne",
  "CatalogNamespace": "742f165671424189aecdfdadf5ea9755",
  "CatalogItemId": "3524134c7a4e4cf2832d8d2a634baef8",
  "InstallLocation": "D:\\\\Epic Games\\\\NuclearThrone",
  "LaunchExecutable": "nuclearthrone.exe"
}
''';
      final ok = parseItemManifest(installed);
      expect(ok, isNotNull);
      expect(ok!.displayName, 'Nuclear Throne');
      expect(ok.appName, 'Turaco');
      expect(ok.launchTarget.kind, LaunchTargetKind.windowsUri);
      expect(
        ok.launchTarget.value,
        'com.epicgames.launcher://apps/'
        '742f165671424189aecdfdadf5ea9755%3A3524134c7a4e4cf2832d8d2a634baef8%3ATuraco'
        '?action=launch&silent=true',
      );
      expect(SourceInference.storeFrom(ok.launchTarget.value), Storefront.epic);

      const incomplete = '''
{
  "bIsIncompleteInstall": true,
  "AppName": "HalfDone",
  "DisplayName": "Still Downloading"
}
''';
      expect(parseItemManifest(incomplete), isNull);
    });

    test('parseItemManifest falls back to AppName URI then exe', () {
      const appOnly = '''
{
  "AppName": "Fortnite",
  "DisplayName": "Fortnite"
}
''';
      final uri = parseItemManifest(appOnly);
      expect(uri, isNotNull);
      expect(
        uri!.launchTarget.value,
        'com.epicgames.launcher://apps/Fortnite?action=launch&silent=true',
      );

      const exeOnly = '''
{
  "DisplayName": "Standalone Title",
  "InstallLocation": "E:\\\\Epic Games\\\\Standalone",
  "LaunchExecutable": "Binaries\\\\Win64\\\\game.exe"
}
''';
      final exe = parseItemManifest(exeOnly);
      expect(exe, isNotNull);
      expect(exe!.launchTarget.kind, LaunchTargetKind.windowsExecutable);
      expect(
        exe.launchTarget.value,
        r'E:\Epic Games\Standalone\Binaries\Win64\game.exe',
      );
      expect(SourceInference.storeFrom(exe.launchTarget.value), Storefront.epic);
    });

    test('buildEpicLaunchUri encodes catalog triple', () {
      expect(
        buildEpicLaunchUri(appName: 'App'),
        'com.epicgames.launcher://apps/App?action=launch&silent=true',
      );
      expect(
        buildEpicLaunchUri(
          appName: 'App',
          catalogNamespace: 'ns',
          catalogItemId: 'item',
        ),
        'com.epicgames.launcher://apps/ns%3Aitem%3AApp?action=launch&silent=true',
      );
      expect(buildEpicLaunchUri(appName: ''), isNull);
    });

    test('parseRegQueryAppDataPath extracts REG_SZ path', () {
      const stdout = r'''
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Epic Games\EpicGamesLauncher
    AppDataPath    REG_SZ    C:\ProgramData\Epic\EpicGamesLauncher\Data\
''';
      expect(
        EpicLibraryScanner.parseRegQueryAppDataPath(stdout),
        r'C:\ProgramData\Epic\EpicGamesLauncher\Data',
      );
    });
  });

  group('EpicLibraryScanner', () {
    test('discovers manifests under HOMEDECK_EPIC_ROOT-style fixture', () async {
      final manifests = win.join(
        r'C:\ProgramData',
        'Epic',
        'EpicGamesLauncher',
        'Data',
        'Manifests',
      );
      final throng = win.join(manifests, 'throne.item');
      final hike = win.join(manifests, 'hike.item');

      final io = MemoryWindowsIo(
        directories: {manifests},
        directoryEntries: {
          manifests: ['throne.item', 'hike.item', 'readme.txt'],
        },
        textFiles: {
          throng: '''
{
  "AppName": "Turaco",
  "DisplayName": "Nuclear Throne",
  "CatalogNamespace": "ns1",
  "CatalogItemId": "item1",
  "InstallLocation": "D:\\\\Epic Games\\\\NuclearThrone",
  "LaunchExecutable": "nuclearthrone.exe"
}
''',
          hike: '''
{
  "AppName": "ShortHike",
  "DisplayName": "A Short Hike",
  "CatalogNamespace": "ns2",
  "CatalogItemId": "item2"
}
''',
        },
      );

      final scanner = EpicLibraryScanner(
        io: io,
        candidateManifestRoots: () => [manifests],
        registryAppDataPath: () async => null,
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(found.map((e) => e.displayName).toList(), [
        'A Short Hike',
        'Nuclear Throne',
      ]);
      expect(
        found.every((e) => e.target.kind == LaunchTargetKind.windowsUri),
        isTrue,
      );
      expect(
        found.every(
          (e) => SourceInference.storeFrom(e.target.value) == Storefront.epic,
        ),
        isTrue,
      );
    });

    test('WindowsAdapter.discoverEpic uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = EpicLibraryScanner(
        io: io,
        candidateManifestRoots: () => const [],
        registryAppDataPath: () async => null,
      );
      final adapter = WindowsAdapter(
        io: io,
        epicScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discoverEpic(), isEmpty);
    });
  });

  group('LibraryController.importEpic', () {
    test('adds new Epic URIs and skips duplicates on re-import', () async {
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverEpicResult: [
            DiscoveredApp(
              displayName: 'Nuclear Throne',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value:
                    'com.epicgames.launcher://apps/Turaco?action=launch&silent=true',
              ),
            ),
            DiscoveredApp(
              displayName: 'A Short Hike',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value:
                    'com.epicgames.launcher://apps/ShortHike?action=launch&silent=true',
              ),
            ),
          ],
        ),
      );

      final first = await harness.controller.importEpic();
      expect(first, 2);
      expect(harness.controller.apps, hasLength(2));
      expect(harness.controller.apps.every((a) => a.store == Storefront.epic),
          isTrue);
      expect(
        harness.controller.home.contains(harness.controller.apps.first.id),
        isFalse,
      );

      final second = await harness.controller.importEpic();
      expect(second, 0);
      expect(harness.controller.apps, hasLength(2));
    });
  });
}
