import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/platform/windows_native_bridge.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/home_screen.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_harness.dart';

void main() {
  testWidgets('1280x800 shows paged Home, featured tile, dock, and chrome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    expect(find.byType(EmptySlot), findsNWidgets(15));
    expect(find.byKey(const ValueKey('tile-add')), findsNothing);
    expect(find.byKey(const Key('now-playing-tile')), findsOneWidget);
    expect(find.text('HomeDeck Menu Music'), findsOneWidget);
    expect(find.byKey(const Key('now-playing-index')), findsOneWidget);
    expect(find.byKey(const Key('home-peek-next')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-dot-1')), findsOneWidget);
    expect(find.text('Arcade Cabinet'), findsNothing);
    expect(find.byType(GlassPanel), findsOneWidget);
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byType(ProfileCluster), findsOneWidget);
    expect(find.byType(TitlePill), findsOneWidget);
    expect(find.byType(StatusCluster), findsOneWidget);
    expect(find.byType(CornerHints), findsOneWidget);
    expect(find.byKey(const Key('tab-home')), findsOneWidget);
    expect(find.byKey(const Key('tab-allApps')), findsOneWidget);
    expect(find.byKey(const Key('dock-home')), findsOneWidget);
    expect(find.byKey(const Key('library-folders')), findsNothing);
    expect(find.byKey(const Key('library-mode-console')), findsNothing);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('(A) Select'), findsOneWidget);
    expect(find.text('(+) Menu'), findsOneWidget);
  });

  testWidgets('demo seed fills Home pins and Library folders', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    // Home title pill shows page dots (not focused-item name).
    expect(
      find.descendant(
        of: find.byKey(const Key('title-pill')),
        matching: find.byKey(const ValueKey('page-dot-0')),
      ),
      findsOneWidget,
    );
    expect(find.byType(EmptySlot), findsWidgets);
    expect(harness.controller.apps, hasLength(24));
    expect(harness.controller.home.contains('app-24'), isTrue);
    expect(harness.controller.home.contains('app-4'), isFalse);
    expect(find.byKey(const Key('library-folders')), findsNothing);
    expect(find.byKey(const Key('library-mode-console')), findsNothing);
    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    expect(find.byKey(const Key('dock-allApps')), findsOneWidget);
    expect(find.byKey(const Key('now-playing-tile')), findsNothing);
    expect(find.byKey(const Key('library-folders')), findsOneWidget);
    expect(find.text('SNES'), findsOneWidget);
    expect(find.text('Nintendo 64'), findsOneWidget);
    await tester.tap(find.byKey(const Key('library-mode-store')));
    await tester.pump();
    expect(find.text('Steam'), findsOneWidget);
    harness.gamepad.emit(GamepadButton.x);
    await tester.pump();
    expect(find.text('SNES'), findsOneWidget);
  });

  testWidgets('arrow keys page past the edge onto a visible tile', (
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
    for (var i = 0; i < 4; i++) {
      await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(focusOn(tester, const ValueKey('tile-app-5')), isTrue);

    await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(focusOn(tester, const ValueKey('tile-app-16')), isTrue);
    expect(find.byKey(const ValueKey('tile-app-16')), findsOneWidget);
    expect(find.byKey(const Key('home-peek-prev')), findsOneWidget);
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
    expect(find.byKey(const Key('games-tab')), findsOneWidget);
    expect(find.byKey(const Key('games-empty')), findsOneWidget);
    expect(find.text('No games yet'), findsOneWidget);
    expect(find.text('Placeholder in milestone 1'), findsNothing);

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

    // Menu → Add game opens the full sheet (Windows A / empty-slot one-shot
    // goes straight to the native Open dialog for Ally Phase2).
    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-add-game')));
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
    await tester.tap(find.byKey(const Key('folder-native')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    expect(find.byKey(const Key('folder-interior')), findsOneWidget);
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
    expect(find.byType(EmptySlot), findsNWidgets(15));
    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('folder-native')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    expect(find.byKey(const Key('menu-add-to-home')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('menu-add-to-home')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-add-to-home')));
    await tester.pump();
    expect(harness.controller.isOnHome('app-1'), isTrue);

    harness.gamepad.emit(GamepadButton.b);
    await tester.pump();
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pump();
    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    expect(find.byType(EmptySlot), findsNWidgets(14));
  });

  testWidgets(
    'Library + menu shows Steam/Start/ROM + storefront scan rows; Home does not',
    (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    expect(find.byKey(const Key('tile-menu')), findsOneWidget);
    expect(find.text('Customize Home'), findsOneWidget);
    expect(find.byKey(const Key('menu-reorder')), findsOneWidget);
    expect(find.byKey(const Key('menu-new-page')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-steam')), findsNothing);
    expect(find.byKey(const Key('menu-scan-start-menu')), findsNothing);
    expect(find.byKey(const Key('menu-scan-roms')), findsNothing);
    expect(find.byKey(const Key('menu-scan-epic')), findsNothing);
    expect(find.byKey(const Key('menu-scan-gog')), findsNothing);
    expect(find.byKey(const Key('menu-scan-ubisoft')), findsNothing);
    expect(find.byKey(const Key('menu-scan-ea')), findsNothing);
    expect(find.byKey(const Key('menu-scan-battlenet')), findsNothing);
    expect(find.byKey(const Key('menu-scan-xbox')), findsNothing);
    harness.gamepad.emit(GamepadButton.b);
    await tester.pump();
    expect(find.byKey(const Key('tile-menu')), findsNothing);

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    expect(find.byKey(const Key('tile-menu')), findsOneWidget);
    expect(find.text('Customize Home'), findsNothing);
    expect(find.byKey(const Key('menu-reorder')), findsNothing);
    expect(find.byKey(const Key('menu-new-page')), findsNothing);
    expect(find.byKey(const Key('menu-scan-steam')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-start-menu')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-roms')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-epic')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-gog')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-ubisoft')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-ea')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-battlenet')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-xbox')), findsOneWidget);
    expect(find.text('Rescan Steam'), findsOneWidget);
    expect(find.text('Rescan Start Menu'), findsOneWidget);
    expect(find.text('Rescan ROM folder'), findsOneWidget);
    expect(find.text('Rescan Epic Games'), findsOneWidget);
    expect(find.text('Rescan GOG'), findsOneWidget);
    expect(find.text('Rescan Ubisoft Connect'), findsOneWidget);
    expect(find.text('Rescan EA App'), findsOneWidget);
    expect(find.text('Rescan Battle.net'), findsOneWidget);
    expect(find.text('Rescan Xbox / Microsoft Store'), findsOneWidget);
  },
  );

  testWidgets('menu-open-hit Semantics opens TileMenu (Ally UIA path)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    expect(find.byKey(const Key('menu-open-hit')), findsOneWidget);
    expect(find.byKey(const Key('tile-menu')), findsNothing);
    expect(find.text('(+) Menu'), findsOneWidget);

    await tester.tap(find.byKey(const Key('menu-open-hit')));
    await tester.pump();
    expect(find.byKey(const Key('tile-menu')), findsOneWidget);
    expect(find.text('Customize Home'), findsOneWidget);
    expect(find.byKey(const Key('menu-reorder')), findsOneWidget);
    expect(find.byKey(const Key('menu-scan-steam')), findsNothing);
  });

  testWidgets('OpenMenuIntent (=) opens TileMenu', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(find.byKey(const Key('tile-menu')), findsOneWidget);
    expect(find.text('Customize Home'), findsOneWidget);
  });

  testWidgets('native openMenu callback opens TileMenu', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    // Simulate runner MethodChannel `openMenu` (WH_KEYBOARD_LL path). On
    // non-Windows the bridge never registers, so invoke the same handler
    // HomeScreen wires when Platform.isWindows.
    final open = WindowsNativeBridge.onOpenMenu;
    if (open == null) {
      // Mac/Linux widget tests: exercise Semantics Invokable instead.
      await tester.tap(find.byKey(const Key('menu-open-hit')));
    } else {
      await open();
    }
    await tester.pump();
    expect(find.byKey(const Key('tile-menu')), findsOneWidget);
    expect(find.text('Customize Home'), findsOneWidget);
  });

  testWidgets('details-open-hit Semantics opens Details menu (Ally UIA path)', (
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
    expect(find.byKey(const Key('details-open-hit')), findsOneWidget);
    expect(find.byKey(const Key('details-menu')), findsNothing);
    expect(find.text('(-) Details'), findsOneWidget);

    await tester.tap(find.byKey(const Key('details-open-hit')));
    await tester.pump();
    expect(find.byKey(const Key('details-menu')), findsOneWidget);
    expect(find.byKey(const Key('details-title')), findsOneWidget);
    expect(find.byKey(const Key('details-remove-from-home')), findsOneWidget);
    expect(find.byKey(const Key('details-remove')), findsOneWidget);
    expect(find.byKey(const Key('details-close')), findsOneWidget);
  });

  testWidgets('OpenDetailsIntent (-) opens Details menu', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    expect(find.byKey(const Key('details-menu')), findsOneWidget);
    expect(find.byKey(const Key('details-remove-from-home')), findsOneWidget);
  });

  testWidgets('native openDetails callback opens Details menu', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();

    // Simulate runner MethodChannel `openDetails` (WH_KEYBOARD_LL path).
    final open = WindowsNativeBridge.onOpenDetails;
    if (open == null) {
      await tester.tap(find.byKey(const Key('details-open-hit')));
    } else {
      await open();
    }
    await tester.pump();
    expect(find.byKey(const Key('details-menu')), findsOneWidget);
    expect(find.byKey(const Key('details-remove-from-home')), findsOneWidget);
  });

  testWidgets('Delete unpins focused Home tile without menu', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    expect(harness.controller.isOnHome('app-1'), isTrue);
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    expect(focusOn(tester, const ValueKey('tile-app-1')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(harness.controller.isOnHome('app-1'), isFalse);
    expect(harness.controller.home.slots, isNot(contains('app-1')));
    expect(harness.controller.apps, hasLength(1));
    expect(find.byKey(const Key('remove-confirm')), findsNothing);
  });

  testWidgets(
    'Delete on Library asks to remove; Enter confirms without launch',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await createHarnessForWidgets(tester);
      await tester.runAsync(() async {
        await harness.controller.addRecord(
          displayName: 'Shelf only',
          target: windowsTarget(
            p.join(harness.directory.path, 'Shelf only.exe'),
          ),
        );
      });
      await pumpHomeDeck(tester, harness);

      await tester.tap(find.byKey(const Key('tab-allApps')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('folder-native')));
      await tester.pump();
      // Tap focuses + launches (AppTile onActivate); baseline then Delete/Enter.
      await tester.tap(find.byKey(const ValueKey('tile-app-1')));
      await tester.pump();
      expect(focusOn(tester, const ValueKey('tile-app-1')), isTrue);
      final launchesAfterFocus = harness.adapter.launchCount;

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(find.byKey(const Key('remove-confirm')), findsOneWidget);
      expect(harness.controller.apps, hasLength(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();

      expect(find.byKey(const Key('remove-confirm')), findsNothing);
      expect(harness.controller.apps, isEmpty);
      expect(harness.adapter.launchCount, launchesAfterFocus);
    },
  );

  testWidgets('Escape cancels Library remove confirm', (tester) async {
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

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('folder-native')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.byKey(const Key('remove-confirm')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('remove-confirm')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
  });

  testWidgets('bare H pins focused Library tile onto Home without menu', (
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

    expect(harness.controller.isOnHome('app-1'), isFalse);
    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('folder-native')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    expect(focusOn(tester, const ValueKey('tile-app-1')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('menu-add-to-home')), findsNothing);
    expect(harness.controller.isOnHome('app-1'), isTrue);
    expect(harness.controller.home.slots, contains('app-1'));
    // H lands on Home with the pinned tile focused (Enter/launch mirror).
    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    expect(focusOn(tester, const ValueKey('tile-app-1')), isTrue);

    // Ally UIA dock → Home must keep the pin, not steal to Now Playing.
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pump();
    expect(focusOn(tester, const ValueKey('tile-app-1')), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(harness.adapter.launchCount, greaterThan(0));
    expect(
      harness.adapter.launched.last.value,
      contains('Shelf only.exe'),
    );
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
    expect(find.byType(EmptySlot), findsNWidgets(14));

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

  testWidgets('Library folders open to a 3-column interior with a hero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('dock-allApps')), findsOneWidget);
    expect(find.byType(GlassPanel), findsNothing);
    await tester.tap(find.byKey(const Key('folder-snes')));
    await tester.pump();
    expect(find.byKey(const Key('folder-interior')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-app-5')), findsOneWidget);
    expect(find.byKey(const Key('library-folder-back')), findsOneWidget);
    expect(find.byKey(const Key('library-mode-console')), findsNothing);
    expect(find.byType(TabDock), findsNothing);

    // First RB force-reveals the dock while staying in the folder.
    harness.gamepad.emit(GamepadButton.rb);
    await tester.pump();
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('folder-interior')), findsOneWidget);
    expect(find.byKey(const Key('dock-allApps')), findsOneWidget);

    // Second RB exits the folder and advances to Home.
    harness.gamepad.emit(GamepadButton.rb);
    await tester.pump();
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('now-playing-tile')), findsOneWidget);

    harness.gamepad.emit(GamepadButton.lb);
    await tester.pump();
    expect(find.byKey(const Key('library-folders')), findsOneWidget);
  });

  testWidgets('Y opens global search across the library', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    harness.gamepad.emit(GamepadButton.y);
    await tester.pump();
    expect(find.byKey(const Key('global-search')), findsOneWidget);
    expect(
      find.text(
        'Press A to open   Press X to navigate   Press B to close',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('search-field')), 'Star');
    await tester.pump();
    expect(find.text('Star Pilot'), findsOneWidget);
    harness.gamepad.emit(GamepadButton.b);
    await tester.pump();
    expect(find.byKey(const Key('global-search')), findsNothing);
  });

  testWidgets('search-open-hit Semantics opens Global Search (Ally UIA path)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    expect(find.byKey(const Key('search-open-hit')), findsOneWidget);
    expect(find.byKey(const Key('global-search')), findsNothing);

    // Dock Search sits under CornerHints for pointer hits; Ally UIA
    // Invoke uses Semantics.onTap (same path as menu/details-open-hit).
    final semantics = tester.ensureSemantics();
    try {
      tester.semantics.tap(find.semantics.byLabel('Open search'));
      await tester.pump();
      expect(find.byKey(const Key('global-search')), findsOneWidget);
      expect(find.byKey(const Key('search-field')), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('native openSearch callback opens Global Search', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    // Simulate runner MethodChannel `openSearch` (WH_KEYBOARD_LL path).
    final open = WindowsNativeBridge.onOpenSearch;
    if (open == null) {
      final semantics = tester.ensureSemantics();
      try {
        tester.semantics.tap(find.semantics.byLabel('Open search'));
        await tester.pump();
        expect(find.byKey(const Key('global-search')), findsOneWidget);
        expect(find.byKey(const Key('search-field')), findsOneWidget);
      } finally {
        semantics.dispose();
      }
      return;
    }
    await open();
    await tester.pump();
    expect(find.byKey(const Key('global-search')), findsOneWidget);
    expect(find.byKey(const Key('search-field')), findsOneWidget);
  });

  testWidgets(
    'notifications-open-hit Semantics opens Notifications (Ally UIA path)',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await createHarnessForWidgets(tester);
      await pumpHomeDeck(tester, harness);

      expect(find.byKey(const Key('notifications-open-hit')), findsOneWidget);
      expect(find.byKey(const Key('notifications-panel')), findsNothing);

      final semantics = tester.ensureSemantics();
      try {
        tester.semantics.tap(find.semantics.byLabel('Open notifications'));
        await tester.pump();
        expect(find.byKey(const Key('notifications-panel')), findsOneWidget);
        expect(find.text('Notifications'), findsWidgets);
        expect(find.text('No notifications'), findsOneWidget);
        expect(find.byKey(const Key('notifications-clear')), findsOneWidget);
        expect(find.byKey(const Key('notifications-close')), findsOneWidget);
      } finally {
        semantics.dispose();
      }

      harness.gamepad.emit(GamepadButton.b);
      await tester.pump();
      expect(find.byKey(const Key('notifications-panel')), findsNothing);
    },
  );

  testWidgets('native openNotifications callback opens Notifications', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    // Simulate runner MethodChannel `openNotifications` (WH_KEYBOARD_LL path).
    final open = WindowsNativeBridge.onOpenNotifications;
    if (open == null) {
      final semantics = tester.ensureSemantics();
      try {
        tester.semantics.tap(find.semantics.byLabel('Open notifications'));
        await tester.pump();
        expect(find.byKey(const Key('notifications-panel')), findsOneWidget);
        expect(find.text('No notifications'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
      return;
    }
    await open();
    await tester.pump();
    expect(find.byKey(const Key('notifications-panel')), findsOneWidget);
    expect(find.text('No notifications'), findsOneWidget);
  });

  testWidgets('OpenNotificationsIntent (T) opens Notifications', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    expect(find.byKey(const Key('notifications-panel')), findsOneWidget);
    expect(find.text('No notifications'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('notifications-panel')), findsNothing);
  });

  testWidgets(
    'friends-open-hit Semantics opens Friends (Ally UIA path)',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await createHarnessForWidgets(tester);
      await pumpHomeDeck(tester, harness);

      expect(find.byKey(const Key('friends-open-hit')), findsOneWidget);
      expect(find.byKey(const Key('friends-panel')), findsNothing);

      final semantics = tester.ensureSemantics();
      try {
        tester.semantics.tap(find.semantics.byLabel('Open friends'));
        await tester.pump();
        expect(find.byKey(const Key('friends-panel')), findsOneWidget);
        expect(find.text('Friends'), findsWidgets);
        expect(find.text('No friends online'), findsOneWidget);
        expect(find.text('0 pinned'), findsOneWidget);
        expect(find.byKey(const Key('friends-close')), findsOneWidget);
      } finally {
        semantics.dispose();
      }

      harness.gamepad.emit(GamepadButton.b);
      await tester.pump();
      expect(find.byKey(const Key('friends-panel')), findsNothing);
    },
  );

  testWidgets('native openFriends callback opens Friends', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    // Simulate runner MethodChannel `openFriends` (WH_KEYBOARD_LL path).
    final open = WindowsNativeBridge.onOpenFriends;
    if (open == null) {
      final semantics = tester.ensureSemantics();
      try {
        tester.semantics.tap(find.semantics.byLabel('Open friends'));
        await tester.pump();
        expect(find.byKey(const Key('friends-panel')), findsOneWidget);
        expect(find.text('No friends online'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
      return;
    }
    await open();
    await tester.pump();
    expect(find.byKey(const Key('friends-panel')), findsOneWidget);
    expect(find.text('No friends online'), findsOneWidget);
  });

  testWidgets('OpenFriendsIntent (F) opens Friends', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(find.byKey(const Key('friends-panel')), findsOneWidget);
    expect(find.text('No friends online'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('friends-panel')), findsNothing);
  });

  testWidgets('OpenRecentsIntent (D) opens Recents drawer', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsOneWidget);
    expect(find.byKey(const Key('recents-empty')), findsOneWidget);
    expect(find.text('Recents'), findsWidgets);
    expect(find.text('No recent apps'), findsOneWidget);
    expect(find.byKey(const Key('recents-close')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsNothing);
  });

  testWidgets('native openRecents callback opens Recents', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    // Simulate runner MethodChannel `openRecents` (WH_KEYBOARD_LL path).
    final open = WindowsNativeBridge.onOpenRecents;
    if (open == null) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.pump();
      expect(find.byKey(const Key('recents-drawer')), findsOneWidget);
      expect(find.byKey(const Key('recents-empty')), findsOneWidget);
      return;
    }
    await open();
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsOneWidget);
    expect(find.byKey(const Key('recents-empty')), findsOneWidget);
  });

  testWidgets('recents-close and B dismiss Recents', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsOneWidget);
    expect(find.byKey(const Key('recents-close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('recents-close')));
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsOneWidget);
    harness.gamepad.emit(GamepadButton.b);
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsNothing);
  });

  testWidgets('native dismissOverlay callback closes Friends', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    expect(find.byKey(const Key('friends-panel')), findsOneWidget);

    // Simulate runner MethodChannel `dismissOverlay` (WH_KEYBOARD_LL Esc).
    final dismiss = WindowsNativeBridge.onDismissOverlay;
    if (dismiss == null) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const Key('friends-panel')), findsNothing);
      return;
    }
    await dismiss();
    await tester.pump();
    expect(find.byKey(const Key('friends-panel')), findsNothing);
  });

  testWidgets('native dismissOverlay closes Notifications and Search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pump();
    expect(find.byKey(const Key('notifications-panel')), findsOneWidget);

    final dismiss = WindowsNativeBridge.onDismissOverlay;
    if (dismiss != null) {
      await dismiss();
    } else {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    }
    await tester.pump();
    expect(find.byKey(const Key('notifications-panel')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.pump();
    expect(find.byKey(const Key('global-search')), findsOneWidget);

    if (dismiss != null) {
      await dismiss();
    } else {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    }
    await tester.pump();
    expect(find.byKey(const Key('global-search')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsOneWidget);

    if (dismiss != null) {
      await dismiss();
    } else {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    }
    await tester.pump();
    expect(find.byKey(const Key('recents-drawer')), findsNothing);
  });

  testWidgets('Games dock tab shows empty chrome (not Placeholder)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const Key('tab-games')));
    await tester.pump();
    expect(find.byKey(const Key('games-tab')), findsOneWidget);
    expect(find.byKey(const Key('games-empty')), findsOneWidget);
    expect(find.text('Games'), findsWidgets);
    expect(find.text('No games yet'), findsOneWidget);
    expect(find.text('Pin games from Library'), findsOneWidget);
    expect(find.text('Placeholder in milestone 1'), findsNothing);
    expect(find.byKey(const Key('dock-games')), findsOneWidget);
  });

  testWidgets(
    'Games / Achievements / Friends empty copy is Semantics-visible (Ally UIA)',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await createHarnessForWidgets(tester);
      await pumpHomeDeck(tester, harness);

      final semantics = tester.ensureSemantics();
      try {
        await tester.tap(find.byKey(const Key('tab-games')));
        await tester.pump();
        expect(find.byKey(const Key('games-empty')), findsOneWidget);
        expect(find.text('No games yet'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('games-empty'))),
          matchesSemantics(label: 'No games yet'),
        );

        await tester.tap(find.byKey(const Key('tab-achievements')));
        await tester.pump();
        expect(find.byKey(const Key('achievements-empty')), findsOneWidget);
        expect(find.text('No achievements yet'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('achievements-empty'))),
          matchesSemantics(label: 'No achievements yet'),
        );

        await tester.tap(find.byKey(const Key('tab-friends')));
        await tester.pump();
        expect(find.byKey(const Key('friends-empty')), findsOneWidget);
        expect(find.text('No friends online'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('friends-empty'))),
          matchesSemantics(label: 'No friends online'),
        );

        // Open Recents via native bridge (or D from Home) — Shortcuts focus
        // can be gone after dock tab taps, same as Ally idle-hide.
        final openRecents = WindowsNativeBridge.onOpenRecents;
        if (openRecents != null) {
          await openRecents();
        } else {
          await tester.tap(find.byKey(const Key('tab-home')));
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
        }
        await tester.pump();
        expect(find.byKey(const Key('recents-empty')), findsOneWidget);
        expect(find.text('No recent apps'), findsOneWidget);
        // Focus/Material may merge overlay chrome; Ally accepts Name containing
        // the empty copy (exact node when container:true boundary wins).
        expect(
          tester.getSemantics(find.byKey(const Key('recents-empty'))).label,
          contains('No recent apps'),
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('Friends dock tab shows empty chrome (not Placeholder)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const Key('tab-friends')));
    await tester.pump();
    expect(find.byKey(const Key('friends-tab')), findsOneWidget);
    expect(find.byKey(const Key('friends-empty')), findsOneWidget);
    expect(find.text('Friends'), findsWidgets);
    expect(find.text('No friends online'), findsOneWidget);
    expect(find.text('Placeholder in milestone 1'), findsNothing);
    expect(find.byKey(const Key('dock-friends')), findsOneWidget);
  });

  testWidgets('Achievements dock tab shows empty chrome (not Placeholder)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const Key('tab-achievements')));
    await tester.pump();
    expect(find.byKey(const Key('achievements-tab')), findsOneWidget);
    expect(find.byKey(const Key('achievements-empty')), findsOneWidget);
    expect(find.text('Achievements'), findsWidgets);
    expect(find.text('No achievements yet'), findsOneWidget);
    expect(find.text('Placeholder in milestone 1'), findsNothing);
    expect(find.byKey(const Key('dock-achievements')), findsOneWidget);
  });

  testWidgets('GotoAchievementsIntent (C) selects Achievements tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pump();
    expect(find.byKey(const Key('achievements-tab')), findsOneWidget);
    expect(find.byKey(const Key('achievements-empty')), findsOneWidget);
    expect(find.text('No achievements yet'), findsOneWidget);
    expect(find.byKey(const Key('dock-achievements')), findsOneWidget);
  });

  testWidgets('native gotoAchievements callback selects Achievements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    final goto = WindowsNativeBridge.onGotoAchievements;
    if (goto == null) {
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.pump();
      expect(find.byKey(const Key('achievements-tab')), findsOneWidget);
      expect(find.text('No achievements yet'), findsOneWidget);
      return;
    }
    await goto();
    await tester.pump();
    expect(find.byKey(const Key('achievements-tab')), findsOneWidget);
    expect(find.byKey(const Key('achievements-empty')), findsOneWidget);
    expect(find.text('No achievements yet'), findsOneWidget);
  });

  testWidgets('title pill follows the focused folder and game', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('folder-snes')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('title-pill')),
        matching: find.text('Music Box'),
      ),
      findsOneWidget,
    );
    harness.gamepad.emit(GamepadButton.b);
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('title-pill')),
        matching: find.text('SNES'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Home title pill shows page dots; Library keeps text title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    // Home: dots live inside the centered pill (not a second under-grid row).
    expect(
      find.descendant(
        of: find.byKey(const Key('title-pill')),
        matching: find.byKey(const ValueKey('page-dot-0')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('title-pill')),
        matching: find.byKey(const ValueKey('page-dot-1')),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('page-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-dot-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('page-dot-1')));
    await tester.pump();
    expect(find.byKey(const Key('home-peek-prev')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    expect(find.byKey(const ValueKey('page-dot-0')), findsNothing);
    expect(find.byKey(const ValueKey('page-dot-1')), findsNothing);
    // Library root: text title (focused folder name), never page dots.
    expect(
      find.descendant(
        of: find.byKey(const Key('title-pill')),
        matching: find.byType(Text),
      ),
      findsWidgets,
    );

    await tester.tap(find.byKey(const Key('folder-snes')));
    await tester.pump();
    expect(find.byKey(const ValueKey('page-dot-0')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('title-pill')),
        matching: find.text('Music Box'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Details can add and remove a Library game from Home', (
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
    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('folder-native')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    harness.gamepad.emit(GamepadButton.back);
    await tester.pump();
    expect(find.byKey(const Key('details-menu')), findsOneWidget);
    expect(find.byKey(const Key('details-add-to-home')), findsOneWidget);
    expect(find.byKey(const Key('details-remove')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-add-to-home')));
    await tester.pump();
    expect(harness.controller.isOnHome('app-1'), isTrue);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('details-open-hit')));
    await tester.pump();
    expect(find.byKey(const Key('details-remove-from-home')), findsOneWidget);
    await tester.tap(find.byKey(const Key('details-remove-from-home')));
    await tester.pump();
    expect(harness.controller.isOnHome('app-1'), isFalse);
  });

  testWidgets('LB/RB never skip a dock tab', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    harness.gamepad.emit(GamepadButton.rb);
    await tester.pump();
    expect(find.text('Games'), findsOneWidget);
    harness.gamepad.emit(GamepadButton.rb);
    await tester.pump();
    expect(find.text('Achievements'), findsOneWidget);
    harness.gamepad.emit(GamepadButton.rb);
    await tester.pump();
    expect(find.text('Friends'), findsOneWidget);
    harness.gamepad.emit(GamepadButton.rb);
    await tester.pump();
    expect(find.byKey(const Key('library-folders')), findsOneWidget);
    harness.gamepad.emit(GamepadButton.rb);
    await tester.pump();
    expect(find.byKey(const Key('now-playing-tile')), findsOneWidget);
  });

  testWidgets(
    'X on Home does not open Library; B at Library root stays there',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await createHarnessForWidgets(tester, seedDemo: true);
      await pumpHomeDeck(tester, harness);

      expect(find.byKey(const Key('dock-home')), findsOneWidget);
      harness.gamepad.emit(GamepadButton.x);
      await tester.pump();
      expect(find.byKey(const Key('now-playing-tile')), findsOneWidget);
      expect(find.byKey(const Key('library-folders')), findsNothing);
      expect(find.byKey(const Key('dock-home')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab-allApps')));
      await tester.pump();
      expect(find.byKey(const Key('dock-allApps')), findsOneWidget);
      expect(find.byKey(const Key('library-folders')), findsOneWidget);
      harness.gamepad.emit(GamepadButton.b);
      await tester.pump();
      expect(find.byKey(const Key('dock-allApps')), findsOneWidget);
      expect(find.byKey(const Key('library-folders')), findsOneWidget);
      expect(find.byKey(const Key('now-playing-tile')), findsNothing);
    },
  );

  testWidgets('Home dock idle-hides then LB reveals and switches tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final priorDelay = HomeScreen.dockIdleHideDelay;
    HomeScreen.dockIdleHideDelay = const Duration(milliseconds: 800);
    addTearDown(() => HomeScreen.dockIdleHideDelay = priorDelay);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('dock-home')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 850));
    expect(find.byType(TabDock), findsNothing);
    expect(find.byKey(const Key('dock-reveal-hit')), findsOneWidget);

    harness.gamepad.emit(GamepadButton.lb);
    await tester.pump();
    // LB wraps Home → Library (allApps); dock must be visible again.
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('dock-allApps')), findsOneWidget);
  });

  testWidgets('Home dock idle-hides then PageDown reveals and advances tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final priorDelay = HomeScreen.dockIdleHideDelay;
    HomeScreen.dockIdleHideDelay = const Duration(milliseconds: 800);
    addTearDown(() => HomeScreen.dockIdleHideDelay = priorDelay);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    await tester.pump(const Duration(milliseconds: 850));
    expect(find.byType(TabDock), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('dock-games')), findsOneWidget);

    // Second PageDown must keep the dock mounted (no opacity remount / UIA 0).
    await tester.pump(const Duration(milliseconds: 1));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('dock-achievements')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(TabDock), findsOneWidget);
  });

  testWidgets('Library root dock idle-hides; bottom hit reveals without tab change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final priorDelay = HomeScreen.dockIdleHideDelay;
    HomeScreen.dockIdleHideDelay = const Duration(milliseconds: 800);
    addTearDown(() => HomeScreen.dockIdleHideDelay = priorDelay);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    expect(find.byKey(const Key('dock-allApps')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 850));
    expect(find.byType(TabDock), findsNothing);

    await tester.tap(find.byKey(const Key('dock-reveal-hit')));
    await tester.pump();
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('dock-allApps')), findsOneWidget);
    expect(find.byKey(const Key('library-folders')), findsOneWidget);
  });

  testWidgets('Inside Library folder bottom hit force-shows dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('folder-snes')));
    await tester.pump();
    expect(find.byKey(const Key('folder-interior')), findsOneWidget);
    expect(find.byType(TabDock), findsNothing);
    expect(find.byKey(const Key('dock-reveal-hit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dock-reveal-hit')));
    await tester.pump();
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('folder-interior')), findsOneWidget);
    expect(find.byKey(const Key('dock-allApps')), findsOneWidget);
  });

  testWidgets('Inside Library folder PageDown force-shows dock without leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const Key('tab-allApps')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('folder-snes')));
    await tester.pump();
    expect(find.byKey(const Key('folder-interior')), findsOneWidget);
    expect(find.byType(TabDock), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    // First PageDown remounts TabDock while staying in the folder.
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('folder-interior')), findsOneWidget);
    expect(find.byKey(const Key('dock-allApps')), findsOneWidget);

    // Second PageDown exits folder and advances the tab.
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    expect(find.byType(TabDock), findsOneWidget);
    expect(find.byKey(const Key('folder-interior')), findsNothing);
  });

  testWidgets('Delete still unpins Home tile after dock idle-hides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final priorDelay = HomeScreen.dockIdleHideDelay;
    HomeScreen.dockIdleHideDelay = const Duration(milliseconds: 800);
    addTearDown(() => HomeScreen.dockIdleHideDelay = priorDelay);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    expect(harness.controller.isOnHome('app-1'), isTrue);
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    expect(focusOn(tester, const ValueKey('tile-app-1')), isTrue);

    await tester.pump(const Duration(milliseconds: 850));
    expect(find.byType(TabDock), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(harness.controller.isOnHome('app-1'), isFalse);
    expect(harness.controller.home.slots, isNot(contains('app-1')));
  });
}
