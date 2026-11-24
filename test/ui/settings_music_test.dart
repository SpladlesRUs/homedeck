import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/models/audio_prefs.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('settings exposes music toggle and volume slider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    expect(harness.musicPlayer.plays, isNotEmpty);

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    expect(find.byKey(const Key('settings-music-enabled')), findsOneWidget);
    expect(find.byKey(const Key('settings-music-volume')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-music-enabled')));
    await tester.pump();
    expect(harness.music.musicEnabled, isFalse);
    expect(harness.controller.state.audio.musicEnabled, isFalse);

    final slider = find.byKey(const Key('settings-music-volume'));
    expect(tester.widget<Slider>(slider).onChanged, isNull);

    await tester.tap(find.byKey(const Key('settings-music-enabled')));
    await tester.pump();
    expect(harness.music.musicEnabled, isTrue);

    await tester.tap(slider);
    await tester.pump();
    expect(harness.music.musicVolume, isNot(AudioPrefs.defaultMusicVolume));
  });

  testWidgets('window blur ducks menu music and focus restores it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(tester);
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.windowMode.emitFocus(false);
    await tester.pump();
    expect(harness.music.isDucked, isTrue);
    expect(harness.musicPlayer.pauseCount, greaterThan(0));

    harness.windowMode.emitFocus(true);
    await tester.pump();
    expect(harness.music.isDucked, isFalse);
    expect(harness.musicPlayer.resumeCount, greaterThan(0));
  });
}
