import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/rom_library.dart';
import 'package:homedeck/platform/windows_adapter.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('RomFolderScanner', () {
    test('recurses common extensions and sets {rom} argsTemplate', () async {
      final root = win.join(r'D:\Roms');
      final nested = win.join(root, 'Switch');
      final zelda = win.join(nested, 'Zelda.nsp');
      final mario = win.join(root, 'Mario.gba');
      final skipTxt = win.join(root, 'readme.txt');
      final emu = win.join(r'C:\Emus', 'yuzu.exe');

      final io = MemoryWindowsIo(
        existing: {zelda, mario, skipTxt, emu},
        directories: {root, nested},
        directoryEntries: {
          root: ['Switch', 'Mario.gba', 'readme.txt'],
          nested: ['Zelda.nsp'],
        },
      );

      final scanner = RomFolderScanner(
        io: io,
        romRoots: () => [root],
        emulatorPath: () => emu,
      );

      final found = await scanner.discover();
      expect(found.map((e) => e.displayName).toList(), ['Mario', 'Zelda']);
      expect(found.every((e) => e.kind == TileKind.emulated), isTrue);
      expect(
        found.every((e) => e.target.kind == LaunchTargetKind.windowsEmulated),
        isTrue,
      );
      expect(found.every((e) => e.target.argsTemplate == '{rom}'), isTrue);
      expect(found.every((e) => e.target.value == emu), isTrue);
      expect(
        found.map((e) => e.target.romPath).toSet(),
        {mario, zelda},
      );
    });

    test('imports with empty emulator when none configured', () async {
      final root = win.join(r'D:\Roms');
      final rom = win.join(root, 'Demo.chd');
      final io = MemoryWindowsIo(
        existing: {rom},
        directories: {root},
        directoryEntries: {
          root: ['Demo.chd'],
        },
      );
      final scanner = RomFolderScanner(
        io: io,
        romRoots: () => [root],
        emulatorPath: () => null,
      );
      final found = await scanner.discover();
      expect(found, hasLength(1));
      expect(found.single.target.value, isEmpty);
      expect(found.single.target.romPath, rom);
    });

    test('WindowsAdapter.discoverRoms uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = RomFolderScanner(
        io: io,
        romRoots: () => const [],
        emulatorPath: () => null,
      );
      final adapter = WindowsAdapter(
        io: io,
        romScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discoverRoms(), isEmpty);
    });
  });

  group('LibraryController.importRoms', () {
    test('adds emulated ROMs and skips duplicates on re-import', () async {
      final emu = win.join(r'C:\Emus', 'mgba.exe');
      final romA = win.join(r'D:\Roms', 'Alpha.gba');
      final romB = win.join(r'D:\Roms', 'Beta.gba');
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverRomsResult: [
            DiscoveredApp(
              displayName: 'Alpha',
              kind: TileKind.emulated,
              target: LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsEmulated,
                value: emu,
                romPath: romA,
                argsTemplate: '{rom}',
              ),
            ),
            DiscoveredApp(
              displayName: 'Beta',
              kind: TileKind.emulated,
              target: LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsEmulated,
                value: emu,
                romPath: romB,
                argsTemplate: '{rom}',
              ),
            ),
          ],
        ),
      );

      final first = await harness.controller.importRoms();
      expect(first, 2);
      expect(harness.controller.apps, hasLength(2));
      expect(
        harness.controller.apps.every((a) => a.kind == TileKind.emulated),
        isTrue,
      );
      expect(
        harness.controller.home.contains(harness.controller.apps.first.id),
        isFalse,
      );

      final second = await harness.controller.importRoms();
      expect(second, 0);
      expect(harness.controller.apps, hasLength(2));
    });

    test('dedupes empty-emulator ROMs by romPath', () async {
      final rom = win.join(r'D:\Roms', 'Solo.zip');
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverRomsResult: [
            DiscoveredApp(
              displayName: 'Solo',
              kind: TileKind.emulated,
              target: LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsEmulated,
                value: '',
                romPath: rom,
                argsTemplate: '{rom}',
              ),
            ),
          ],
        ),
      );
      expect(await harness.controller.importRoms(), 1);
      expect(await harness.controller.importRoms(), 0);
      expect(harness.controller.apps.single.targetFor(AppPlatform.windows)!.value,
          isEmpty);
    });

    test('reuses the single obvious library emulator', () async {
      final emu = win.join(r'C:\Emus', 'dolphin.exe');
      final existingRom = win.join(r'D:\Roms', 'Old.iso');
      final harness = await createHarness();
      await harness.controller.addRecord(
        displayName: 'Old',
        kind: TileKind.emulated,
        target: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsEmulated,
          value: emu,
          romPath: existingRom,
          argsTemplate: '{rom}',
        ),
      );

      expect(harness.controller.resolveRomEmulator(), emu);

      final adapter = harness.adapter;
      adapter.discoverRomsResult = [
        DiscoveredApp(
          displayName: 'New',
          kind: TileKind.emulated,
          target: LaunchTarget(
            platform: AppPlatform.windows,
            kind: LaunchTargetKind.windowsEmulated,
            value: emu,
            romPath: win.join(r'D:\Roms', 'New.iso'),
            argsTemplate: '{rom}',
          ),
        ),
      ];
      await harness.controller.importRoms();
      expect(adapter.lastRomEmulator, emu);
    });

    test('persists romRoot in library state JSON', () async {
      final harness = await createHarness();
      final root = win.join(r'D:\Roms');
      await harness.controller.setRomRoot(root);
      expect(harness.controller.state.romRoot, root);
      final encoded = harness.controller.state.toJson();
      expect(encoded['romRoot'], root);
    });
  });
}
