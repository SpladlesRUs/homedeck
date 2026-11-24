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

void main() {
  const size = Size(1280, 800);

  testWidgets('capture 1280x800 after screenshot with demo grid', (tester) async {
    if (Platform.environment['SAVE_PROOF'] != '1') {
      return;
    }
    await _loadFonts();
    _setView(tester, size);

    HomeScreen.tickClock = false;
    addTearDown(() => HomeScreen.tickClock = true);

    final outDir = _outDir();
    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await _pumpApp(tester, harness);
    await _save(tester, p.join(outDir.path, 'after-1280x800.png'));
    await _save(tester, p.join(outDir.path, '01-home-grid-tiles.png'));

    await sendArrow(tester, LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 200));
    await _save(tester, p.join(outDir.path, '02-focus-state.png'));
  });

  testWidgets('capture launch error overlay', (tester) async {
    if (Platform.environment['SAVE_PROOF'] != '1') {
      return;
    }
    await _loadFonts();
    _setView(tester, size);
    HomeScreen.tickClock = false;
    addTearDown(() => HomeScreen.tickClock = true);

    final harness = await createHarnessForWidgets(tester);
    await addSampleAppsForWidgets(
      tester,
      harness,
      count: 1,
      validation: LaunchFailure.missingFile(),
    );
    await _pumpApp(tester, harness);
    await tester.tap(find.byKey(const ValueKey('tile-app-1')));
    await tester.pump(const Duration(milliseconds: 300));
    await _save(tester, p.join(_outDir().path, '03-launch-error.png'));
  });

  testWidgets('capture fullscreen badge', (tester) async {
    if (Platform.environment['SAVE_PROOF'] != '1') {
      return;
    }
    await _loadFonts();
    _setView(tester, size);
    HomeScreen.tickClock = false;
    addTearDown(() => HomeScreen.tickClock = true);

    final harness = await createHarnessForWidgets(tester, seedDemo: true);
    await harness.windowMode.apply(true, false);
    await _pumpApp(tester, harness);
    await _save(tester, p.join(_outDir().path, '04-fullscreen.png'));
  });
}

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Directory _outDir() {
  final dir = Directory(p.join(Directory.current.path, 'docs', 'proof', 'ui'));
  dir.createSync(recursive: true);
  return dir;
}

Future<void> _pumpApp(WidgetTester tester, Harness harness) async {
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
}

Future<void> _loadFonts() async {
  const material = '/opt/flutter/bin/cache/artifacts/material_fonts';
  await _loadFamily('Roboto', [
    '$material/Roboto-Regular.ttf',
    '$material/Roboto-Medium.ttf',
    '$material/Roboto-Bold.ttf',
  ]);
  await _loadFamily('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
}

Future<void> _loadFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var added = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    added = true;
  }
  if (added) {
    await loader.load();
  }
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
