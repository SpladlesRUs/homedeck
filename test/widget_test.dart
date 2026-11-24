import 'package:flutter_test/flutter_test.dart';
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

    expect(find.text('HomeDeck'), findsOneWidget);
    expect(find.text('Tile 1'), findsOneWidget);
    expect(find.text('Tile 2'), findsOneWidget);
    expect(find.text('Add app'), findsOneWidget);
  });
}
