import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_harness.dart';

void main() {
  testWidgets('1280x800 shows an 8x3 grid, glass panel, dock, and chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    expect(find.byType(EmptySlot), findsNWidgets(24));
    expect(find.byKey(const ValueKey('tile-add')), findsNothing);
    expect(find.text('Empty slot'), findsOneWidget);
    expect(find.text('Arcade Cabinet'), findsNothing);
    expect(find.byType(GlassPanel), findsOneWidget);
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byType(ProfileCluster), findsOneWidget);
    expect(find.byType(TitlePill), findsOneWidget);
    expect(find.byType(StatusCluster), findsOneWidget);
    expect(find.byType(CornerHints), findsOneWidget);
    expect(find.byKey(const Key('tab-home')), findsOneWidget);
    expect(find.byKey(const Key('tab-allApps')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('(A) Select'), findsOneWidget);
    expect(find.text('(+) Menu'), findsOneWidget);
  });

  testWidgets('demo seed fills the 8x3 grid only when enabled', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    expect(find.text('Arcade Cabinet'), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    expect(find.byType(EmptySlot), findsWidgets);
    expect(harness.controller.apps, hasLength(24));
    expect(harness.controller.home.contains('app-24'), isTrue);
    expect(harness.controller.home.contains('app-4'), isFalse);
    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tile-app-24')), findsOneWidget);
    expect(find.text('SNES'), findsOneWidget);
    expect(find.text('Nintendo 64'), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-mode-store')));
    await tester.pump();
    expect(find.text('Steam'), findsOneWidget);
    harness.gamepad.emit(GamepadButton.x);
    await tester.pump();
    expect(find.text('SNES'), findsOneWidget);
  });

  testWidgets('arrow keys wrap to the next page after 24 tiles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 25);
    await pumpHomeDeck(tester, harness);

    expect(find.byKey(const ValueKey('page-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-dot-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    for (var i = 0; i < 23; i++) {
      await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(focusOn(tester, const ValueKey('tile-app-24')), isTrue);

    await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(focusOn(tester, const ValueKey('tile-app-25')), isTrue);
    expect(find.byKey(const ValueKey('tile-app-25')), findsOneWidget);
  });

  testWidgets('gamepad D-pad, A, B, LB/RB drive the same intents', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 3);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    harness.gamepad.emit(GamepadButton.dpadRight);
    await tester.pump();
    expect(focusOn(tester, const ValueKey('tile-app-2')), isTrue);

    harness.gamepad.emit(GamepadButton.rb);
    await tester.pump();
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Placeholder in milestone 1'), findsOneWidget);

    harness.gamepad.emit(GamepadButton.lb);
    await tester.pump();
    expect(find.byKey(const ValueKey('tile-app-2')), findsOneWidget);

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);

    harness.gamepad.emit(GamepadButton.b);
    await tester.pump();
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('title pill is centered on the 1280x800 midpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    final screen = tester.getSize(find.byType(MaterialApp));
    final pill = tester.getRect(find.byKey(const Key('title-pill')));
    expect(screen.width, 1280);
    expect((pill.center.dx - screen.width / 2).abs(), lessThan(1.0));
  });

  testWidgets('add sheet supports native URI and emulated ROM', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    harness.adapter.fileQueue.addAll([
      r'C:\Emulators\RetroArch.exe',
      r'C:\Roms\Star Pilot.z64',
    ]);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byType(EmptySlot).first);
    await tester.pump();
    expect(find.byKey(const Key('add-tile-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('add-uri-field')),
      'steam://rungameid/440',
    );
    await tester.enterText(find.byKey(const Key('add-name-field')), 'Portal');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('add-save'))).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('add-save')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.kind.name, 'native');
    expect(
      harness.controller.apps.single.targets.values.single.value,
      'steam://rungameid/440',
    );
    expect(find.byKey(const Key('add-tile-sheet')), findsNothing);

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-add-game')));
    await tester.pump();
    expect(find.byKey(const Key('add-tile-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-kind-emulated')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-pick-emulator')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-pick-rom')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('add-name-field')), 'Star ROM');
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-save')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pump();
    expect(harness.controller.apps, hasLength(2));
    expect(harness.controller.apps.last.kind.name, 'emulated');
    expect(
      harness.controller.apps.last.targets.values.single.romPath,
      contains('Star Pilot.z64'),
    );
  });

  testWidgets('unpinning from Home keeps the game in Library', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    expect(find.byKey(const Key('tile-menu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu-remove-from-home')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tile-app-1')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(
      harness.controller.isOnHome(harness.controller.apps.first.id),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    expect(find.text('Tile 1'), findsOneWidget);
  });

  testWidgets('Library menu pins a game onto an empty Home slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await tester.runAsync(() async {
      await harness.controller.addRecord(
        displayName: 'Shelf only',
        target: windowsTarget(p.join(harness.directory.path, 'Shelf only.exe')),
      );
    });
    await pumpHomeDeck(tester, harness);

    expect(find.byKey(const ValueKey('tile-app-1')), findsNothing);
    expect(find.byType(EmptySlot), findsNWidgets(24));
    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    expect(find.byKey(const Key('menu-add-to-home')), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu-add-to-home')));
    await tester.pump();
    expect(harness.controller.isOnHome('app-1'), isTrue);

    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    expect(find.byType(EmptySlot), findsNWidgets(23));
  });

  testWidgets('Home Move mode rearranges tiles and keeps empty slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-move')));
    await tester.pump();
    expect(find.byKey(const Key('move-mode-hint')), findsOneWidget);

    harness.gamepad.emit(GamepadButton.dpadRight);
    await tester.pump();
    expect(harness.controller.home[0], isNull);
    expect(harness.controller.home[1], 'app-1');
    expect(find.byType(EmptySlot), findsNWidgets(23));

    harness.gamepad.emit(GamepadButton.a);
    await tester.pump();
    expect(find.byKey(const Key('move-mode-hint')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
  });

  testWidgets('battery meter hides when percent is unknown', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    harness.deviceStatus.batteryPercent = null;
    await pumpHomeDeck(tester, harness);
    expect(find.byKey(const Key('battery-percent')), findsNothing);
  });
}
