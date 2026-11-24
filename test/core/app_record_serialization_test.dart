import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/audio_prefs.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/home_layout.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_kind.dart';
import 'package:homedeck/core/models/tile_layout.dart';
import 'package:path/path.dart' as p;

void main() {
  test('AppRecord round-trips JSON with a Windows-only target', () {
    final record = AppRecord(
      id: '11111111-1111-4111-8111-111111111111',
      displayName: 'Photo Deck',
      iconRef: p.posix.join(
        'icons',
        '11111111-1111-4111-8111-111111111111.png',
      ),
      position: 2,
      category: 'apps',
      favorite: true,
      targets: {
        AppPlatform.windows: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsExecutable,
          value: p.windows.join(
            r'\\server\share',
            'Photo Deck',
            'PhotoDeck.exe',
          ),
          arguments: const ['--fullscreen'],
        ),
      },
    );

    final decoded = AppRecord.fromJson(record.toJson());
    expect(decoded, record);
    expect(decoded.targets.containsKey(AppPlatform.macos), isFalse);
    expect(decoded.targets.containsKey(AppPlatform.linux), isFalse);
    expect(decoded.targets.containsKey(AppPlatform.android), isFalse);
    expect(decoded.iconRef, isNot(contains(r'\')));
    expect(p.isRelative(decoded.iconRef!), isTrue);
  });

  test('HomeDeckState round-trips mixed optional fields', () {
    final state = HomeDeckState(
      apps: [
        AppRecord(
          id: 'a',
          displayName: 'A',
          position: 0,
          targets: {
            AppPlatform.windows: LaunchTarget(
              platform: AppPlatform.windows,
              kind: LaunchTargetKind.windowsShortcut,
              value: p.windows.join('Games', 'A.lnk'),
            ),
          },
        ),
      ],
      layout: const TileLayout(orderedIds: ['a']),
      window: const WindowPrefs(fullscreen: true, borderless: true),
      audio: const AudioPrefs(
        musicEnabled: false,
        musicVolume: 0.2,
        uiClicksEnabled: false,
      ),
    );

    expect(HomeDeckState.fromJson(state.toJson()), state);
  });

  test('emulated tile round-trips kind, ROM path, and args template', () {
    final record = AppRecord(
      id: 'emu-1',
      displayName: 'Star Pilot',
      position: 0,
      kind: TileKind.emulated,
      console: ConsoleSystem.n64,
      targets: {
        AppPlatform.windows: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsEmulated,
          value: p.windows.join('Emulators', 'RetroArch.exe'),
          romPath: p.windows.join('Roms', 'Star Pilot.z64'),
          argsTemplate: '{rom}',
        ),
      },
    );
    final decoded = AppRecord.fromJson(record.toJson());
    expect(decoded, record);
    expect(decoded.kind, TileKind.emulated);
    expect(decoded.console, ConsoleSystem.n64);
    expect(decoded.targets.values.single.romPath, contains('Star Pilot.z64'));
  });

  test(
    'HomeLayout keeps empty slots and round-trips separately from library',
    () {
      const home = HomeLayout(slots: ['a', null, 'b', null]);
      expect(home.unpinning('a').slots, [null, null, 'b', null]);
      expect(home.pinning('c').slots, ['a', 'c', 'b', null]);
      final state = HomeDeckState(
        apps: [
          const AppRecord(id: 'a', displayName: 'A', position: 0),
          const AppRecord(id: 'b', displayName: 'B', position: 1),
        ],
        home: home,
      );
      expect(HomeDeckState.fromJson(state.toJson()).home, home);
    },
  );

  test('legacy JSON without kind defaults to native', () {
    final decoded = AppRecord.fromJson({
      'id': 'legacy',
      'displayName': 'Old Tile',
      'position': 0,
      'targets': {
        'windows': {
          'platform': 'windows',
          'kind': 'windowsExecutable',
          'value': r'C:\Games\Old.exe',
        },
      },
    });
    expect(decoded.kind, TileKind.native);
  });
}
