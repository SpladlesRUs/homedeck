import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('arrow keys move focus across tiles', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(tester, harness, count: 3);
    await pumpHomeDeck(tester, harness);

    final first = find.byKey(const ValueKey('tile-app-1'));
    final second = find.byKey(const ValueKey('tile-app-2'));
    final third = find.byKey(const ValueKey('tile-app-3'));
    expect(first, findsOneWidget);

    await tester.tap(first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(focusOn(tester, const ValueKey('tile-app-1')), isTrue);

    await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(focusOn(tester, const ValueKey('tile-app-2')), isTrue);

    await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    expect(focusOn(tester, const ValueKey('tile-app-3')), isTrue);

    await sendArrow(tester, LogicalKeyboardKey.arrowLeft);
    expect(focusOn(tester, const ValueKey('tile-app-2')), isTrue);

    expect(second, findsOneWidget);
    expect(third, findsOneWidget);
    expect(find.text('Add app'), findsOneWidget);
    expect(addTileId, isNotEmpty);
  });
}
