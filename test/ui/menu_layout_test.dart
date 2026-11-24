import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:material_ui/material_ui.dart';

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

    expect(find.byType(EmptySlot), findsNWidgets(23));
    expect(find.byKey(const ValueKey('tile-add')), findsOneWidget);
    expect(find.text('Add app'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('tile-app-24')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-dot-1')), findsOneWidget);
  });

  testWidgets('arrow keys wrap to the next page after 24 tiles', (tester) async {
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
