import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('official HomeDeck icon is used in the header', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 1);
    await pumpHomeDeck(tester, harness);

    expect(find.byType(HomeDeckMark), findsWidgets);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(HomeDeckMark).first,
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      HomeDeckMark.assetPath,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
