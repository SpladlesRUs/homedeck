import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_harness.dart';

void main() {
  testWidgets('Settings toggle persists Return to HomeDeck when game exits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    expect(harness.controller.state.window.restoreOnExit, isTrue);
    await tester.tap(find.byKey(const Key('settings-restore-on-exit')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(harness.controller.state.window.restoreOnExit, isFalse);
  });

  testWidgets('game exit unducks music and leaves launch fullscreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    expect(harness.controller.state.window.restoreOnExit, isTrue);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(harness.adapter.launchCount, greaterThan(0));
    expect(harness.windowMode.isFullscreen, isTrue);
    expect(harness.music.isDucked, isTrue);

    // Simulate runner WM_HOMEDECK_GAME_EXIT → gameExited (native already
    // left chrome + foregrounded; Dart unducks + persists prefs).
    await harness.windowMode.apply(false, harness.windowMode.isBorderless);
    await harness.music.unduck();
    await harness.controller.setWindowPrefs(
      WindowPrefs(
        fullscreen: harness.windowMode.isFullscreen,
        borderless: harness.windowMode.isBorderless,
        fullscreenOnLaunch: harness.controller.state.window.fullscreenOnLaunch,
        restoreOnExit: harness.controller.state.window.restoreOnExit,
      ),
    );
    await tester.pump();

    expect(harness.windowMode.isFullscreen, isFalse);
    expect(harness.music.isDucked, isFalse);
  });

  testWidgets('restoreOnExit OFF keeps launch fullscreen after simulated exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await tester.runAsync(() async {
      await harness.controller.setWindowPrefs(
        const WindowPrefs(restoreOnExit: false),
      );
      await harness.controller.addRecord(
        displayName: 'StayFullscreen',
        target: windowsTarget(
          p.join(harness.directory.path, 'StayFullscreen.exe'),
        ),
        pinToHome: true,
        homeSlot: 0,
      );
    });
    await pumpHomeDeck(tester, harness);

    expect(harness.controller.state.window.restoreOnExit, isFalse);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(harness.windowMode.isFullscreen, isTrue);

    // With restore OFF the runner skips SetFullscreen(false) / foreground —
    // Dart must not force a restore either.
    expect(harness.windowMode.isFullscreen, isTrue);
  });
}
