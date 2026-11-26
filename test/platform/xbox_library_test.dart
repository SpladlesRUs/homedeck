import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_adapter.dart';
import 'package:homedeck/platform/xbox_library.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('Xbox URI helpers', () {
    test('buildMsXboxLaunchUri and AUMID helpers', () {
      expect(
        buildMsXboxLaunchUri(productId: '9NBLGGH51MQR'),
        'msxbox://game/?id=9NBLGGH51MQR',
      );
      expect(buildMsXboxLaunchUri(productId: ''), isNull);
      expect(
        buildMsWindowsStoreLaunchUri(productId: '9NBLGGH51MQR'),
        'ms-windows-store://pdp/?ProductId=9NBLGGH51MQR',
      );
      expect(
        buildXboxAumidUri(
          packageFamilyName: 'Publisher.Game_8wekyb3d8bbwe',
          applicationId: 'App',
        ),
        r'shell:AppsFolder\Publisher.Game_8wekyb3d8bbwe!App',
      );
      expect(
        normalizeXboxAumidUri('Publisher.Game_8wekyb3d8bbwe!App'),
        r'shell:AppsFolder\Publisher.Game_8wekyb3d8bbwe!App',
      );
      expect(productIdFromInfoFileName('xboxgame-9NBLGGH51MQR.info'), '9NBLGGH51MQR');
    });

    test('installEntryToManifest prefers msxbox URI', () async {
      final m = await installEntryToManifest(
        const XboxInstallEntry(
          installDir: r'D:\XboxGames\Sea of Thieves\Content',
          displayName: 'Sea of Thieves',
          productId: '9NBLGGH4R32H',
        ),
      );
      expect(m, isNotNull);
      expect(m!.displayName, 'Sea of Thieves');
      expect(m.launchTarget.value, 'msxbox://game/?id=9NBLGGH4R32H');
      expect(
        SourceInference.storeFrom(m.launchTarget.value),
        Storefront.xbox,
      );
    });

    test('parseXboxInfo uses productId and URI', () async {
      final m = await parseXboxInfo(
        '{"name":"Forza Horizon 5","productId":"9PNJXVCVDQHC"}',
        installRoot: r'C:\XboxGames\ForzaHorizon5\Content',
      );
      expect(m, isNotNull);
      expect(m!.displayName, 'Forza Horizon 5');
      expect(m.launchTarget.value, 'msxbox://game/?id=9PNJXVCVDQHC');
      expect(SourceInference.storeFrom(m.launchTarget.value), Storefront.xbox);
    });

    test('parseXboxPackageFiles prefers StoreId msxbox URI', () async {
      const config = '''
<Game>
  <StoreId>9NBLGGH51MQR</StoreId>
  <ShellVisuals DefaultDisplayName="Sample Xbox Title" />
</Game>
''';
      const manifest = '''
<Package>
  <Identity Name="Publisher.SampleGame" Publisher="CN=Test" Version="1.0.0.0" />
  <Applications>
    <Application Id="App" Executable="Game.exe" />
  </Applications>
  <Properties>
    <DisplayName>Sample Xbox Title</DisplayName>
  </Properties>
</Package>
''';
      final m = await parseXboxPackageFiles(
        configXml: config,
        manifestXml: manifest,
        installRoot: r'D:\XboxGames\Sample\Content',
      );
      expect(m, isNotNull);
      expect(m!.displayName, 'Sample Xbox Title');
      expect(m.launchTarget.value, 'msxbox://game/?id=9NBLGGH51MQR');
    });
  });

  group('XboxLibraryScanner', () {
    test('discovers xboxgame info under HOMEDECK_XBOX_ROOT-style fixture',
        () async {
      final games = win.join(r'C:\XboxGames');
      final forza = win.join(games, 'ForzaHorizon5');
      final content = win.join(forza, 'Content');
      final info = win.join(content, 'xboxgame-9PNJXVCVDQHC.info');

      final io = MemoryWindowsIo(
        directories: {games, forza, content},
        directoryEntries: {
          games: ['ForzaHorizon5'],
          forza: ['Content'],
          content: ['xboxgame-9PNJXVCVDQHC.info', 'ForzaHorizon5.exe'],
        },
        textFiles: {
          info:
              '{"name":"Forza Horizon 5","productId":"9PNJXVCVDQHC"}',
        },
      );

      final scanner = XboxLibraryScanner(
        io: io,
        candidateRoots: () => [games],
        registryInstalls: () async => const [],
      );

      final found = await scanner.discover();
      expect(found, hasLength(1));
      expect(found.single.displayName, 'Forza Horizon 5');
      expect(found.single.target.kind, LaunchTargetKind.windowsUri);
      expect(found.single.target.value, 'msxbox://game/?id=9PNJXVCVDQHC');
      expect(
        SourceInference.storeFrom(found.single.target.value),
        Storefront.xbox,
      );
    });

    test('skips ACL-denied WindowsApps and still imports fixture root',
        () async {
      final windowsApps = win.join(r'C:\Program Files\WindowsApps');
      final games = win.join(r'C:\XboxGames');
      final smoke = win.join(games, 'SmokeXb1');
      final content = win.join(smoke, 'Content');
      final info = win.join(content, 'xboxgame-SMOKEXB1.info');

      final io = MemoryWindowsIo(
        directories: {windowsApps, games, smoke, content},
        directoryEntries: {
          // WindowsApps exists but listing throws Access Denied (real ACL).
          games: ['SmokeXb1'],
          smoke: ['Content'],
          content: ['xboxgame-SMOKEXB1.info'],
        },
        permissionDenied: {windowsApps},
        textFiles: {
          info: '{"name":"SmokeXb1","productId":"SMOKEXB1"}',
        },
      );

      final scanner = XboxLibraryScanner(
        io: io,
        // Denied root first — must not abort HOMEDECK_XBOX_ROOT / XboxGames.
        candidateRoots: () => [windowsApps, games],
        registryInstalls: () async => const [],
      );

      final found = await scanner.discover();
      expect(found, hasLength(1));
      expect(found.single.displayName, 'SmokeXb1');
      expect(found.single.target.value, 'msxbox://game/?id=SMOKEXB1');
      expect(
        SourceInference.storeFrom(found.single.target.value),
        Storefront.xbox,
      );
    });

    test('discovers MicrosoftGame.config folders as msxbox URIs', () async {
      final root = win.join(r'D:\XboxGames\SeaOfThieves\Content');
      final config = win.join(root, 'MicrosoftGame.config');

      final io = MemoryWindowsIo(
        directories: {root},
        existing: {config},
        directoryEntries: {
          root: ['MicrosoftGame.config', 'SeaofThieves.exe'],
        },
        textFiles: {
          config: '''
<Game>
  <StoreId>9NBLGGH4R32H</StoreId>
  <ShellVisuals DefaultDisplayName="Sea of Thieves" />
</Game>
''',
        },
      );

      final scanner = XboxLibraryScanner(
        io: io,
        candidateRoots: () => [root],
        registryInstalls: () async => const [],
      );

      final found = await scanner.discover();
      expect(found, hasLength(1));
      expect(found.single.displayName, 'Sea of Thieves');
      expect(found.single.target.value, 'msxbox://game/?id=9NBLGGH4R32H');
    });

    test('WindowsAdapter.discoverXbox uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = XboxLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registryInstalls: () async => const [],
      );
      final adapter = WindowsAdapter(
        io: io,
        xboxScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discoverXbox(), isEmpty);
    });
  });

  group('LibraryController.importXbox', () {
    test('adds new Xbox URIs and skips duplicates on re-import', () async {
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverXboxResult: [
            DiscoveredApp(
              displayName: 'Forza Horizon 5',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'msxbox://game/?id=9PNJXVCVDQHC',
              ),
            ),
            DiscoveredApp(
              displayName: 'Sea of Thieves',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'msxbox://game/?id=9NBLGGH4R32H',
              ),
            ),
          ],
        ),
      );

      final first = await harness.controller.importXbox();
      expect(first, 2);
      expect(harness.controller.apps, hasLength(2));
      expect(
        harness.controller.apps.every((a) => a.store == Storefront.xbox),
        isTrue,
      );
      expect(
        harness.controller.home.contains(harness.controller.apps.first.id),
        isFalse,
      );

      final second = await harness.controller.importXbox();
      expect(second, 0);
      expect(harness.controller.apps, hasLength(2));
    });
  });
}
