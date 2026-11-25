import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/audio_prefs.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_platform_adapter.dart';
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

  testWidgets('keyboard S scans Steam without opening Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverResult: [
          DiscoveredApp(
            displayName: 'Portal',
            target: const LaunchTarget(
              platform: AppPlatform.windows,
              kind: LaunchTargetKind.windowsUri,
              value: 'steam://rungameid/400',
            ),
          ),
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('settings-scan-steam')), findsNothing);
    expect(harness.controller.apps, hasLength(1));
    expect(
      harness.controller.apps.single.targets.values.single.value,
      'steam://rungameid/400',
    );
  });

  testWidgets('settings Steam scan imports discovered games', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await createHarnessForWidgets(
      tester,
      adapter: FakePlatformAdapter(
        discoverResult: [
          DiscoveredApp(
            displayName: 'Portal',
            target: const LaunchTarget(
              platform: AppPlatform.windows,
              kind: LaunchTargetKind.windowsUri,
              value: 'steam://rungameid/400',
            ),
          ),
        ],
      ),
    );
    await pumpHomeDeck(tester, harness);
    await tester.pump();

    harness.gamepad.emit(GamepadButton.start);
    await tester.pump();
    await tester.tap(find.byKey(const Key('menu-settings')));
    await tester.pump();

    final scan = find.byKey(const Key('settings-scan-steam'));
    expect(scan, findsOneWidget);
    await tester.ensureVisible(scan);
    await tester.pump();
    await tester.tap(scan);
    await tester.pump();
    await tester.runAsync(() async {
      // Let importDiscovered finish disk writes outside the fake-async zone.
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.apps.single.displayName, 'Portal');
    expect(
      harness.controller.apps.single.targets.values.single.value,
      'steam://rungameid/400',
    );
    expect(find.byKey(const Key('settings-scan-steam-message')), findsOneWidget);
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
