import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('1280x800 shows a 5x3 grid with empty slots and a dock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    expect(find.byType(EmptySlot), findsNWidgets(14));
    expect(find.byKey(const ValueKey('tile-add')), findsOneWidget);
    expect(find.text('Add app'), findsOneWidget);
    expect(find.text('Arcade Cabinet'), findsNothing);
    expect(find.byType(BottomDock), findsOneWidget);
    expect(find.byType(ProfileBadge), findsOneWidget);
    expect(find.byType(PageDots), findsOneWidget);
    expect(find.byKey(const Key('dock-__dock_settings__')), findsOneWidget);
    expect(find.byKey(const Key('dock-__dock_add__')), findsOneWidget);
    expect(find.byKey(const Key('dock-__dock_fullscreen__')), findsOneWidget);
    expect(find.byKey(const Key('dock-__dock_library__')), findsOneWidget);
    expect(find.byKey(const Key('dock-__dock_exit__')), findsOneWidget);
  });

  testWidgets('demo seed fills the grid only when enabled', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await pumpHomeDeck(tester, harness);

    expect(find.text('Arcade Cabinet'), findsOneWidget);
    expect(find.text('Star Chart'), findsNothing);
    expect(find.byKey(const ValueKey('page-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-dot-1')), findsOneWidget);
    expect(find.byKey(const Key('page-next')), findsOneWidget);
  });

  testWidgets('arrow keys wrap to the next page', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 16);
    await pumpHomeDeck(tester, harness);

    expect(find.byKey(const ValueKey('page-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-dot-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    for (var i = 0; i < 14; i++) {
      await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(focusOn(tester, const ValueKey('tile-app-15')), isTrue);

    await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(focusOn(tester, const ValueKey('tile-app-16')), isTrue);
    expect(find.byKey(const ValueKey('tile-app-16')), findsOneWidget);
    expect(find.byKey(const Key('page-next')), findsNothing);
    expect(find.byKey(const Key('page-prev')), findsOneWidget);
  });
}
