import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/audio_prefs.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  testWidgets('settings exposes music toggle and volume slider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    expect(harness.musicPlayer.plays, isNotEmpty);

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    expect(find.byKey(const Key('settings-music-enabled')), findsOneWidget);
    expect(find.byKey(const Key('settings-music-volume')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-music-enabled')));
    await tester.pump();
    expect(harness.music.musicEnabled, isFalse);
    expect(harness.controller.state.audio.musicEnabled, isFalse);

    final slider = find.byKey(const Key('settings-music-volume'));
    expect(tester.widget<Slider>(slider).onChanged, isNull);

    await tester.tap(find.byKey(const Key('settings-music-enabled')));
    await tester.pump();
    expect(harness.music.musicEnabled, isTrue);

    await tester.tap(slider);
    await tester.pump();
    expect(harness.music.musicVolume, isNot(AudioPrefs.defaultMusicVolume));
  });

  testWidgets('keyboard S scans Steam without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
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
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-steam')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(
      harness.controller.apps.single.targets.values.single.value,
      'steam://rungameid/400',
    );
  });

  testWidgets('settings Steam scan imports discovered games', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
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
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-steam'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      // Let importDiscovered finish disk writes outside the fake-async zone.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Portal');
    expect(
      harness.controller.apps.single.targets.values.single.value,
      'steam://rungameid/400',
    );
    expect(find.byKey(const Key('settings-scan-steam-message')), findsOneWidget);
  });

  testWidgets('bare P imports Start Menu apps without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverStartMenuResult: [
          DiscoveredApp(
            displayName: 'Notepad',
            target: const LaunchTarget(
              platform: AppPlatform.windows,
              kind: LaunchTargetKind.windowsExecutable,
              value: r'C:\Windows\System32\notepad.exe',
            ),
          ),
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-start-menu')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Notepad');
  });

  testWidgets('settings Start Menu scan imports discovered apps', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverStartMenuResult: [
          DiscoveredApp(
            displayName: 'Notepad',
            target: const LaunchTarget(
              platform: AppPlatform.windows,
              kind: LaunchTargetKind.windowsExecutable,
              value: r'C:\Windows\System32\notepad.exe',
            ),
          ),
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-start-menu'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Notepad');
    expect(
      find.byKey(const Key('settings-scan-start-menu-message')),
      findsOneWidget,
    );
  });

  testWidgets('bare R imports ROM tiles without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverRomsResult: [
          DiscoveredApp(
            displayName: 'Zelda',
            kind: TileKind.emulated,
            target: const LaunchTarget(
              platform: AppPlatform.windows,
              kind: LaunchTargetKind.windowsEmulated,
              value: r'C:\Emus\yuzu.exe',
              romPath: r'D:\Roms\Zelda.nsp',
              argsTemplate: '{rom}',
            ),
          ),
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-roms')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Zelda');
    expect(harness.controller.apps.single.kind, TileKind.emulated);
  });

  testWidgets('settings ROM scan imports discovered ROMs', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverRomsResult: [
          DiscoveredApp(
            displayName: 'Mario',
            kind: TileKind.emulated,
            target: const LaunchTarget(
              platform: AppPlatform.windows,
              kind: LaunchTargetKind.windowsEmulated,
              value: '',
              romPath: r'D:\Roms\Mario.gba',
              argsTemplate: '{rom}',
            ),
          ),
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-roms'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Mario');
    expect(find.byKey(const Key('settings-scan-roms-message')), findsOneWidget);
  });

  testWidgets('bare E imports Epic titles without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
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
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-epic')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Nuclear Throne');
    expect(harness.controller.apps.single.store, Storefront.epic);
  });

  testWidgets('settings Epic scan imports discovered titles', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverEpicResult: [
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
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-epic'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'A Short Hike');
    expect(find.byKey(const Key('settings-scan-epic-message')), findsOneWidget);
  });

  testWidgets('bare G imports GOG titles without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
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
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-gog')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'The Witcher 3');
    expect(harness.controller.apps.single.store, Storefront.gog);
  });

  testWidgets('settings GOG scan imports discovered titles', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverGogResult: [
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
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-gog'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'A Short Hike');
    expect(find.byKey(const Key('settings-scan-gog-message')), findsOneWidget);
  });

  testWidgets('bare U imports Ubisoft titles without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
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
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-ubisoft')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Far Cry 5');
    expect(harness.controller.apps.single.store, Storefront.ubisoft);
  });

  testWidgets('settings Ubisoft scan imports discovered titles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverUbisoftResult: [
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
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-ubisoft'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(
      harness.controller.apps.single.displayName,
      "Assassin's Creed Odyssey",
    );
    expect(
      find.byKey(const Key('settings-scan-ubisoft-message')),
      findsOneWidget,
    );
  });

  testWidgets('bare O imports EA titles without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
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
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-ea')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Bejeweled 3');
    expect(harness.controller.apps.single.store, Storefront.ea);
  });

  testWidgets('settings EA scan imports discovered titles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverEaResult: [
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
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-ea'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Dead Space');
    expect(
      find.byKey(const Key('settings-scan-ea-message')),
      findsOneWidget,
    );
  });

  testWidgets('bare N imports Battle.net titles without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
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
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-battlenet')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Diablo III');
    expect(harness.controller.apps.single.store, Storefront.battlenet);
  });

  testWidgets('settings Battle.net scan imports discovered titles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverBattlenetResult: [
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
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-battlenet'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'World of Warcraft');
    expect(
      find.byKey(const Key('settings-scan-battlenet-message')),
      findsOneWidget,
    );
  });

  testWidgets('window blur ducks menu music and focus restores it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.windowMode.emitFocus(false);
    await tester.pump();
    expect(harness.music.isDucked, isTrue);
    expect(harness.musicPlayer.pauseCount, greaterThan(0));

    harness.windowMode.emitFocus(true);
    await tester.pump();
    expect(harness.music.isDucked, isFalse);
    expect(harness.musicPlayer.resumeCount, greaterThan(0));
  });
}
