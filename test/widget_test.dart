import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/test_harness.dart';

void main() {
  testWidgets('HomeDeck opens on the home grid', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 2);
    await pumpHomeDeck(tester, harness);

    expect(find.byType(HomeDeckMark), findsWidgets);
    expect(find.text('Tile 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-app-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-app-2')), findsOneWidget);
    expect(find.byType(EmptySlot), findsWidgets);
  });
}
