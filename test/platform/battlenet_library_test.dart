import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/battlenet_library.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_adapter.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('Battle.net product.db / URI helpers', () {
    test('parseProductDb and buildBattlenetLaunchUri', () {
      final bytes = encodeProductDb(const [
        BattlenetInstallEntry(
          uid: 'diablo3',
          productCode: 'D3',
          installDir: r'D:\Games\Diablo III',
        ),
        BattlenetInstallEntry(
          uid: 'wow',
          productCode: 'WoW',
          installDir: r'C:\Program Files (x86)\World of Warcraft',
        ),
        BattlenetInstallEntry(
          uid: 'battle.net',
          productCode: 'battle.net',
          installDir: r'C:\Program Files (x86)\Battle.net',
        ),
      ]);
      final parsed = parseProductDb(Uint8List.fromList(bytes));
      expect(parsed, hasLength(2));
      expect(parsed.map((e) => e.productCode).toSet(), {'D3', 'WoW'});
      expect(
        buildBattlenetLaunchUri(productCode: 'WoW'),
        'battlenet://WoW/',
      );
      expect(buildBattlenetLaunchUri(productCode: ''), isNull);
      expect(uidFromUninstallString(r'"C:\Battle.net\Battle.net.exe" --uid=wow --uninstall'), 'wow');
      expect(productCodeForUid('prometheus'), 'Pro');
      expect(isAgentComponent('agent'), isTrue);
    });

    test('installEntryToManifest prefers battlenet URI', () async {
      final m = await installEntryToManifest(
        const BattlenetInstallEntry(
          uid: 'diablo3',
          productCode: 'D3',
          installDir: r'D:\Games\Diablo III',
          displayName: 'Diablo III',
        ),
      );
      expect(m, isNotNull);
      expect(m!.displayName, 'Diablo III');
      expect(m.launchTarget.value, 'battlenet://D3/');
      expect(
        SourceInference.storeFrom(m.launchTarget.value),
        Storefront.battlenet,
      );
    });

    test('parseBattlenetInfo uses productCode and URI', () async {
      final m = await parseBattlenetInfo(
        '{"name":"Overwatch 2","uid":"prometheus","productCode":"Pro"}',
        installRoot: r'C:\Games\Overwatch',
      );
      expect(m, isNotNull);
      expect(m!.displayName, 'Overwatch 2');
      expect(m.launchTarget.value, 'battlenet://Pro/');
      expect(SourceInference.storeFrom(m.launchTarget.value), Storefront.battlenet);
    });
  });

  group('BattlenetLibraryScanner', () {
    test('discovers battlenetgame info under fixture root', () async {
      final games = win.join(r'C:\Battle.net\Games');
      final d3 = win.join(games, 'Diablo III');
      final wow = win.join(games, 'World of Warcraft');
      final d3Info = win.join(d3, 'battlenetgame-D3.info');
      final wowInfo = win.join(wow, 'battlenetgame-WoW.info');

      final io = MemoryWindowsIo(
        directories: {games, d3, wow},
        directoryEntries: {
          games: ['Diablo III', 'World of Warcraft', 'cache'],
          d3: ['battlenetgame-D3.info', 'Diablo III.exe'],
          wow: ['battlenetgame-WoW.info'],
        },
        textFiles: {
          d3Info: '{"name":"Diablo III","uid":"diablo3","productCode":"D3"}',
          wowInfo:
              '{"name":"World of Warcraft","uid":"wow","productCode":"WoW"}',
        },
      );

      final scanner = BattlenetLibraryScanner(
        io: io,
        candidateRoots: () => [games],
        registryInstalls: () async => const [],
        productDbInstalls: () async => const [],
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(found.map((e) => e.displayName).toList(), [
        'Diablo III',
        'World of Warcraft',
      ]);
      expect(
        found.every((e) => e.target.kind == LaunchTargetKind.windowsUri),
        isTrue,
      );
      expect(
        found.every(
          (e) =>
              SourceInference.storeFrom(e.target.value) == Storefront.battlenet,
        ),
        isTrue,
      );
    });

    test('discovers product.db installs as battlenet URIs', () async {
      final io = MemoryWindowsIo();
      final scanner = BattlenetLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registryInstalls: () async => const [],
        productDbInstalls: () async => const [
          BattlenetInstallEntry(
            uid: 'diablo3',
            productCode: 'D3',
            installDir: r'D:\Games\Diablo III',
            displayName: 'Diablo III',
          ),
          BattlenetInstallEntry(
            uid: 'wow',
            productCode: 'WoW',
            installDir: r'C:\Games\World of Warcraft',
            displayName: 'World of Warcraft',
          ),
        ],
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(
        found.map((e) => e.target.value).toSet(),
        {'battlenet://D3/', 'battlenet://WoW/'},
      );
    });

    test('WindowsAdapter.discoverBattlenet uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = BattlenetLibraryScanner(
        io: io,
        candidateRoots: () => const [],
        registryInstalls: () async => const [],
        productDbInstalls: () async => const [],
      );
      final adapter = WindowsAdapter(
        io: io,
        battlenetScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discoverBattlenet(), isEmpty);
    });
  });

  group('LibraryController.importBattlenet', () {
    test('adds new Battle.net URIs and skips duplicates on re-import', () async {
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverBattlenetResult: [
            DiscoveredApp(
              displayName: 'Diablo III',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'battlenet://D3/',
              ),
            ),
            DiscoveredApp(
              displayName: 'World of Warcraft',
              target: const LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsUri,
                value: 'battlenet://WoW/',
              ),
            ),
          ],
        ),
      );

      final first = await harness.controller.importBattlenet();
      expect(first, 2);
      expect(harness.controller.apps, hasLength(2));
      expect(
        harness.controller.apps.every((a) => a.store == Storefront.battlenet),
        isTrue,
      );
      expect(
        harness.controller.home.contains(harness.controller.apps.first.id),
        isFalse,
      );

      final second = await harness.controller.importBattlenet();
      expect(second, 0);
      expect(harness.controller.apps, hasLength(2));
    });
  });
}
