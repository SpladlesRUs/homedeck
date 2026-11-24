import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('launch error overlay shows moved-or-missing copy', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(
      tester,
      harness,
      count: 1,
      validation: LaunchFailure.missingFile(),
    );
    await pumpHomeDeck(tester, harness);

    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('launch-error-dialog')), findsOneWidget);
    expect(find.byKey(const Key('launch-error-title')), findsOneWidget);
    expect(
      find.text(LaunchFailureKind.missingFile.headline),
      findsOneWidget,
    );
    expect(find.text('Tile 1'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('launch-error-dialog')), findsNothing);
  });

  testWidgets('permission, drive, and launch failures each have distinct copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final kind in LaunchFailureKind.values) {
      final harness = await createHarnessForWidgets(tester);
      await addSampleAppsForWidgets(
        tester,
        harness,
        count: 1,
        validation: LaunchFailure(kind: kind, message: kind.headline),
      );
      await pumpHomeDeck(tester, harness);
      await tester.tap(find.byKey(const ValueKey('tile-app-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(kind.headline), findsOneWidget);
      await tester.tap(find.byKey(const Key('launch-error-ok')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }
  });
}
