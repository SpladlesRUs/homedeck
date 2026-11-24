import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/app.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_harness.dart';

/// Writes labeled Linux-shared-UI proof screenshots when SAVE_PROOF=1.
void main() {
  testWidgets('capture Linux shared UI proof screenshots', (tester) async {
    if (Platform.environment['SAVE_PROOF'] != '1') {
      return;
    }

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    HomeScreen.tickClock = false;
    addTearDown(() => HomeScreen.tickClock = true);

    final harness = await createHarnessForWidgets(tester);
    const names = [
      'Arcade Cabinet',
      'Star Pilot',
      'Photo Deck',
      'Workshop',
      'Missing Drive Game',
    ];
    for (final name in names) {
      await tester.runAsync(() async {
        await harness.controller.addRecord(
          displayName: name,
          target: windowsTarget(
            p.join(harness.directory.path, '$name.exe'),
          ),
        );
      });
    }

    final outDir = Directory(
      p.join(Directory.current.path, 'docs', 'proof', 'linux-shared-ui'),
    );
    outDir.createSync(recursive: true);

    await tester.pumpWidget(
      RepaintBoundary(
        child: HomeDeckApp(
          controller: harness.controller,
          windowMode: harness.windowMode,
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(HomeDeckApp));
    await tester.runAsync(() async {
      await precacheImage(const AssetImage(HomeDeckMark.assetPath), context);
    });
    await tester.pump(const Duration(milliseconds: 400));
    await _save(tester, p.join(outDir.path, '01-home-grid-tiles.png'));

    await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 250));
    await _save(tester, p.join(outDir.path, '02-focus-state.png'));

    harness.adapter.validation = LaunchFailure.removedDrive();
    await tester.ensureVisible(find.byKey(const ValueKey('tile-app-5')));
    await tester.tap(find.byKey(const ValueKey('tile-app-5')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('launch-error-dialog')), findsOneWidget);
    await _save(tester, p.join(outDir.path, '03-launch-error.png'));

    await tester.tap(find.byKey(const Key('launch-error-ok')));
    await tester.pump(const Duration(milliseconds: 250));
    await harness.windowMode.apply(true, false);
    await tester.pump(const Duration(milliseconds: 250));
    await _save(tester, p.join(outDir.path, '04-fullscreen.png'));
  });
}

Future<void> _save(WidgetTester tester, String path) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
