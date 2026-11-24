import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:homedeck/core/models/launch_target.dart';
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
    );

    expect(HomeDeckState.fromJson(state.toJson()), state);
  });
}
