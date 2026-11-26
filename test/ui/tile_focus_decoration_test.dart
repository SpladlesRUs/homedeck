import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/ui/app_tile.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_harness.dart';

void main() {
  const metrics = HomeDeckMetrics(
    size: Size(1280, 800),
    scale: 1,
    columns: 8,
    rows: 3,
    gap: 8,
    padding: 28,
  );

  testWidgets('focused TileFace uses animated cyan→gold ring and scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: TileFace(
                metrics: metrics,
                focused: true,
                hovered: false,
                child: const ColoredBox(color: Color(0xFF112233)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('tile-focus-ring')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-face-calm')), findsNothing);

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, TileFace.focusedScale);

    final ring = tester.widget<Container>(
      find.byKey(const ValueKey('tile-focus-ring')),
    );
    final decoration = ring.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as SweepGradient;
    expect(gradient.colors, TileFace.focusRingColors);
    expect(gradient.colors, isNot(contains(HomeDeckColors.purple)));

    final state = tester.state<TileFaceState>(find.byType(TileFace));
    expect(state.spinController.isAnimating, isTrue);

    final before = gradient.transform;
    await tester.pump(const Duration(milliseconds: 600));
    final afterRing = tester.widget<Container>(
      find.byKey(const ValueKey('tile-focus-ring')),
    );
    final afterGradient =
        (afterRing.decoration! as BoxDecoration).gradient! as SweepGradient;
    expect(afterGradient.transform, isNot(equals(before)));
  });

  testWidgets('unfocused TileFace stays calm without ring', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 96,
              height: 96,
              child: TileFace(
                metrics: metrics,
                focused: false,
                hovered: false,
                child: const ColoredBox(color: Color(0xFF112233)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('tile-face-calm')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-focus-ring')), findsNothing);

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.0);

    final face = tester.widget<Container>(
      find.byKey(const ValueKey('tile-face-calm')),
    );
    final decoration = face.decoration! as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.boxShadow, isEmpty);

    final state = tester.state<TileFaceState>(find.byType(TileFace));
    expect(state.spinController.isAnimating, isFalse);
  });

  testWidgets('focused empty Home slot shows the same focus ring', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);

    final empty = find.byKey(const ValueKey('home-slot-0'));
    expect(empty, findsOneWidget);
    await tester.tap(empty);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(focusOn(tester, const ValueKey('home-slot-0')), isTrue);
    expect(
      find.descendant(
        of: empty,
        matching: find.byKey(const ValueKey('tile-focus-ring')),
      ),
      findsOneWidget,
    );
    expect(find.byType(EmptySlot), findsWidgets);
  });
}
