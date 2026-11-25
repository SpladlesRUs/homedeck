import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_harness.dart';

void main() {
  testWidgets('launch enters fullscreen when Fullscreen on launch is ON', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    expect(harness.controller.state.window.fullscreenOnLaunch, isTrue);
    expect(harness.windowMode.isFullscreen, isFalse);

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
  });

  testWidgets('launch stays windowed when Fullscreen on launch is OFF', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await tester.runAsync(() async {
      await harness.controller.setWindowPrefs(
        const WindowPrefs(fullscreenOnLaunch: false),
      );
      await harness.controller.addRecord(
        displayName: 'Windowed',
        target: windowsTarget(p.join(harness.directory.path, 'Windowed.exe')),
        pinToHome: true,
        homeSlot: 0,
      );
    });
    await pumpHomeDeck(tester, harness);

    expect(harness.controller.state.window.fullscreenOnLaunch, isFalse);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(harness.adapter.launchCount, greaterThan(0));
    expect(harness.windowMode.isFullscreen, isFalse);
  });

  testWidgets('Settings toggle persists Fullscreen on launch', (tester) async {
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

    expect(harness.controller.state.window.fullscreenOnLaunch, isTrue);
    await tester.tap(find.byKey(const Key('settings-fullscreen-on-launch')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(harness.controller.state.window.fullscreenOnLaunch, isFalse);
  });
}
