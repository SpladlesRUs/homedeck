import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/library_groups.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/windows_adapter.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_harness.dart';

void main() {
  test('expandLaunchArgs substitutes {rom} and honors quotes', () {
    expect(expandLaunchArgs(romPath: r'C:\Roms\Game.iso'), [r'C:\Roms\Game.iso']);
    expect(
      expandLaunchArgs(
        romPath: r'D:\Roms\Star Pilot.z64',
        template: '-L cores/mupen64plus_libretro.dll "{rom}"',
      ),
      ['-L', 'cores/mupen64plus_libretro.dll', r'D:\Roms\Star Pilot.z64'],
    );
  });

  test('WindowsPaths.isLaunchUri accepts store schemes only', () {
    expect(WindowsPaths.isLaunchUri('steam://rungameid/440'), isTrue);
    expect(
      WindowsPaths.isLaunchUri('com.epicgames.launcher://apps/abc'),
      isTrue,
    );
    expect(WindowsPaths.isLaunchUri('goggalaxy://openGameView/123'), isTrue);
    expect(WindowsPaths.isLaunchUri('uplay://launch/1234/0'), isTrue);
    expect(WindowsPaths.isLaunchUri('ubisoftconnect://launch/1234/0'), isTrue);
    expect(WindowsPaths.isLaunchUri('msxbox://game/?id=abc'), isTrue);
    expect(WindowsPaths.isLaunchUri(r'C:\Games\Star.exe'), isFalse);
    expect(WindowsPaths.isLaunchUri('https://example.com/game'), isFalse);
    expect(WindowsPaths.isLaunchUri('file:///C:/Games/a.exe'), isFalse);
  });

  test('native URI launches through cmd start and skips file checks', () async {
    final io = MemoryWindowsIo();
    final adapter = WindowsAdapter(
      io: io,
      filePicker: ({required label, required extensions}) async => null,
    );
    final target = LaunchTarget(
      platform: AppPlatform.windows,
      kind: LaunchTargetKind.windowsUri,
      value: 'steam://rungameid/440',
    );
    expect(await adapter.validateTarget(target), isNull);
    expect(await adapter.launch(target), isA<LaunchSuccess>());
    expect(io.launches, hasLength(1));
    expect(io.launches.single.executable, 'steam://rungameid/440');
    expect(io.launches.single.shortcut, isTrue);
  });

  test('emulated launch expands the ROM into the emulator argv', () async {
    final emulator = p.windows.join('Emulators', 'RetroArch.exe');
    final rom = p.windows.join('Roms', 'Star Pilot.z64');
    final io = MemoryWindowsIo(existing: {emulator, rom});
    final adapter = WindowsAdapter(
      io: io,
      filePicker: ({required label, required extensions}) async => null,
    );
    final target = LaunchTarget(
      platform: AppPlatform.windows,
      kind: LaunchTargetKind.windowsEmulated,
      value: emulator,
      romPath: rom,
      argsTemplate: '-L cores/n64.dll "{rom}"',
    );
    expect(await adapter.launch(target), isA<LaunchSuccess>());
    expect(io.launches, hasLength(1));
    expect(io.launches.single.executable, emulator);
    expect(io.launches.single.arguments, ['-L', 'cores/n64.dll', rom]);
    expect(io.launches.single.shortcut, isTrue);
  });

  test('missing ROM uses the same overlay failure kind as a missing exe', () async {
    final emulator = p.windows.join('Emulators', 'RetroArch.exe');
    final rom = p.windows.join('Roms', 'Missing.z64');
    final io = MemoryWindowsIo(existing: {emulator});
    final adapter = WindowsAdapter(
      io: io,
      filePicker: ({required label, required extensions}) async => null,
    );
    final target = LaunchTarget(
      platform: AppPlatform.windows,
      kind: LaunchTargetKind.windowsEmulated,
      value: emulator,
      romPath: rom,
      argsTemplate: '{rom}',
    );
    final failure = await adapter.validateTarget(target);
    expect(failure?.kind, LaunchFailureKind.missingFile);
  });

  test('library controller stores native vs emulated tile kinds', () async {
    final harness = await createHarness();
    await harness.controller.addRecord(
      displayName: 'Portal',
      target: const LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: 'steam://rungameid/400',
      ),
    );
    await harness.controller.addRecord(
      displayName: 'Star Pilot ROM',
      kind: TileKind.emulated,
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsEmulated,
        value: p.join(harness.directory.path, 'retroarch.exe'),
        romPath: p.join(harness.directory.path, 'star.z64'),
        argsTemplate: '{rom}',
      ),
    );
    expect(harness.controller.apps, hasLength(2));
    expect(harness.controller.apps[0].kind, TileKind.native);
    expect(harness.controller.apps[1].kind, TileKind.emulated);
    expect(harness.controller.apps[1].targets.values.first.romPath, endsWith('star.z64'));
    expect(harness.controller.apps[0].store, Storefront.steam);
    expect(harness.controller.apps[1].console, ConsoleSystem.n64);
    expect(harness.controller.isOnHome(harness.controller.apps[0].id), isFalse);
  });

  test('library groups emulated by console and native by store', () {
    expect(SourceInference.storeFrom('steam://rungameid/440'), Storefront.steam);
    expect(
      SourceInference.storeFrom(r'C:\Program Files\Epic Games\Fortnite\Fortnite.exe'),
      Storefront.epic,
    );
    expect(
      SourceInference.storeFrom('uplay://launch/1234/0'),
      Storefront.ubisoft,
    );
    expect(
      SourceInference.consoleFrom(romPath: r'D:\Roms\game.sfc'),
      ConsoleSystem.snes,
    );
    expect(
      SourceInference.consoleFrom(emulatorPath: r'C:\Emu\pcsx2.exe'),
      ConsoleSystem.ps2,
    );
    final sections = groupLibrary(
      const [
        AppRecord(
          id: '1',
          displayName: 'Zelda',
          position: 0,
          kind: TileKind.emulated,
          console: ConsoleSystem.snes,
        ),
        AppRecord(
          id: '2',
          displayName: 'Portal',
          position: 1,
          store: Storefront.steam,
        ),
      ],
      mode: LibraryGroupMode.console,
    );
    expect(sections.map((s) => s.title), ['SNES', 'Native']);
    expect(ConsoleSystem.snes.slug, 'snes');
    expect(ConsoleSystem.n64.slug, 'nintendo-64');
    expect(ConsoleSystem.arcade.slug, 'arcade');
    expect(slugForGroupTitle('SNES'), 'snes');
    expect(folderFocusId('Nintendo 64'), '__homedeck_folder_nintendo-64');
  });
}
