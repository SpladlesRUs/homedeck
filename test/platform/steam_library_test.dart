import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/steam_library.dart';
import 'package:homedeck/platform/windows_adapter.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('VDF / ACF parsing', () {
    test('parseLibraryFolderPaths reads modern and legacy layouts', () {
      const modern = '''
"libraryfolders"
{
	"0"
	{
		"path"		"C:\\\\Program Files (x86)\\\\Steam"
		"label"		""
	}
	"1"
	{
		"path"		"D:\\\\SteamLibrary"
	}
}
''';
      expect(
        parseLibraryFolderPaths(modern),
        [
          r'C:\Program Files (x86)\Steam',
          r'D:\SteamLibrary',
        ],
      );

      const legacy = '''
"LibraryFolders"
{
	"TimeNextStatsReport"		"123"
	"1"		"E:\\\\Games\\\\Steam"
}
''';
      expect(parseLibraryFolderPaths(legacy), [r'E:\Games\Steam']);
    });

    test('parseAppManifest requires installed StateFlags and name', () {
      const installed = '''
"AppState"
{
	"appid"		"440"
	"Universe"		"1"
	"name"		"Team Fortress 2"
	"StateFlags"		"4"
	"installdir"		"Team Fortress 2"
}
''';
      final ok = parseAppManifest(installed);
      expect(ok, isNotNull);
      expect(ok!.appId, '440');
      expect(ok.name, 'Team Fortress 2');

      const downloading = '''
"AppState"
{
	"appid"		"570"
	"name"		"Dota 2"
	"StateFlags"		"2"
}
''';
      expect(parseAppManifest(downloading), isNull);
    });

    test('parseRegQuerySteamPath extracts REG_SZ path', () {
      const stdout = r'''
HKEY_CURRENT_USER\Software\Valve\Steam
    SteamPath    REG_SZ    C:\Program Files (x86)\Steam
''';
      expect(
        SteamLibraryScanner.parseRegQuerySteamPath(stdout),
        r'C:\Program Files (x86)\Steam',
      );
    });
  });

  group('SteamLibraryScanner', () {
    test('discovers games across primary and secondary libraries', () async {
      final primary = win.join(r'C:\Program Files (x86)', 'Steam');
      final secondary = win.join(r'D:', 'SteamLibrary');
      final primaryApps = win.join(primary, 'steamapps');
      final secondaryApps = win.join(secondary, 'steamapps');
      final vdf = win.join(primaryApps, 'libraryfolders.vdf');
      final tf2 = win.join(primaryApps, 'appmanifest_440.acf');
      final portal = win.join(secondaryApps, 'appmanifest_400.acf');

      final io = MemoryWindowsIo(
        existing: {
          win.join(primary, 'steam.exe'),
          vdf,
          tf2,
          portal,
        },
        directories: {
          primary,
          secondary,
          primaryApps,
          secondaryApps,
        },
        directoryEntries: {
          primaryApps: [
            'libraryfolders.vdf',
            'appmanifest_440.acf',
            'common',
          ],
          secondaryApps: [
            'appmanifest_400.acf',
          ],
        },
        textFiles: {
          vdf: '''
"libraryfolders"
{
	"0"
	{
		"path"		"${primary.replaceAll(r'\', r'\\')}"
	}
	"1"
	{
		"path"		"${secondary.replaceAll(r'\', r'\\')}"
	}
}
''',
          tf2: '''
"AppState"
{
	"appid"		"440"
	"name"		"Team Fortress 2"
	"StateFlags"		"4"
}
''',
          portal: '''
"AppState"
{
	"appid"		"400"
	"name"		"Portal"
	"StateFlags"		"4"
}
''',
        },
      );

      final scanner = SteamLibraryScanner(
        io: io,
        candidateRoots: () => [primary],
        registrySteamPath: () async => primary,
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(found.map((e) => e.displayName).toList(), [
        'Portal',
        'Team Fortress 2',
      ]);
      expect(
        found.map((e) => e.target.value).toSet(),
        {
          'steam://rungameid/400',
          'steam://rungameid/440',
        },
      );
      expect(
        found.every((e) => e.target.kind == LaunchTargetKind.windowsUri),
        isTrue,
      );
    });

    test('WindowsAdapter.discover uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = SteamLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registrySteamPath: () async => null,
      );
      final adapter = WindowsAdapter(
        io: io,
        steamScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discover(), isEmpty);
    });
  });

  group('LibraryController.importDiscovered', () {
    test('adds new Steam URIs and skips duplicates', () async {
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverResult: [
            DiscoveredApp(
              displayName: 'Portal',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'steam://rungameid/400',
              ),
            ),
            DiscoveredApp(
              displayName: 'Team Fortress 2',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'steam://rungameid/440',
              ),
            ),
          ],
        ),
      );
      await harness.controller.addRecord(
        displayName: 'Portal (manual)',
        target: const LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsUri,
          value: 'steam://rungameid/400',
        ),
      );

      final added = await harness.controller.importDiscovered();
      expect(added, 1);
      expect(harness.controller.apps, hasLength(2));
      expect(
        harness.controller.apps.map((a) => a.displayName),
        containsAll(['Portal (manual)', 'Team Fortress 2']),
      );
      expect(harness.controller.home.contains(harness.controller.apps.last.id), isFalse);
    });
  });
}
