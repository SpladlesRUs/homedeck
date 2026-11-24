import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:homedeck/core/models/home_layout.dart';
import 'package:homedeck/core/models/tile_layout.dart';
import 'package:homedeck/core/preferences_repository.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  test('TileLayout reorders and serializes', () {
    const layout = TileLayout(orderedIds: ['a', 'b', 'c', 'd']);
    expect(layout.reordering(0, 2).orderedIds, ['b', 'c', 'a', 'd']);
    expect(layout.move('b', TraversalDirection.right, 2).orderedIds, [
      'a',
      'c',
      'b',
      'd',
    ]);
    expect(TileLayout.fromJson(layout.toJson()), layout);
  });

  test('failed save does not publish a tile without library.json', () async {
    final harness = await createHarness();
    final dir = harness.directory;
    // A file where the support directory should be — create(recursive) fails.
    final blocker = File(p.join(dir.path, 'not-a-dir'));
    await blocker.writeAsString('x', flush: true);
    final broken = AppPaths(Directory(p.join(blocker.path, 'HomeDeck')));
    final prefs = PreferencesRepository(broken);
    final controller = LibraryController(
      adapter: FakePlatformAdapter(),
      preferences: prefs,
      icons: IconCache(harness.paths),
    );
    await controller.load();
    await expectLater(
      controller.addRecord(
        displayName: 'Ghost',
        target: LaunchTarget(
          platform: AppPlatform.windows,
          kind: LaunchTargetKind.windowsExecutable,
          value: p.join(dir.path, 'Ghost.exe'),
        ),
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(controller.apps, isEmpty);
    expect(File(p.join(blocker.path, 'HomeDeck', 'library.json')).existsSync(), isFalse);
  });

  test('library layout persists across repository instances', () async {
    final harness = await createHarness();
    await harness.controller.addRecord(
      displayName: 'One',
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsExecutable,
        value: p.join(harness.directory.path, 'One.exe'),
      ),
    );
    await harness.controller.addRecord(
      displayName: 'Two',
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsExecutable,
        value: p.join(harness.directory.path, 'Two.exe'),
      ),
    );
    await harness.controller.addRecord(
      displayName: 'Three',
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsExecutable,
        value: p.join(harness.directory.path, 'Three.exe'),
      ),
    );
    await harness.controller.pinToHome(harness.controller.apps[0].id, at: 0);
    await harness.controller.pinToHome(harness.controller.apps[1].id, at: 2);
    await harness.controller.reorder(0, 2);

    final reloaded = LibraryController(
      adapter: FakePlatformAdapter(),
      preferences: PreferencesRepository(harness.paths),
      icons: IconCache(harness.paths),
    );
    await reloaded.load();

    expect(reloaded.apps.map((app) => app.displayName).toList(), [
      'Two',
      'Three',
      'One',
    ]);
    expect(
      reloaded.state.layout.orderedIds,
      harness.controller.state.layout.orderedIds,
    );
    expect(reloaded.state.home.slots[0], harness.controller.apps[2].id);
    expect(reloaded.state.home.slots[2], harness.controller.apps[0].id);
    expect(reloaded.isOnHome(reloaded.apps[1].id), isFalse);
    await reloaded.unpinFromHome(reloaded.apps[2].id);
    expect(reloaded.apps, hasLength(3));
    expect(reloaded.isOnHome(reloaded.apps[2].id), isFalse);
    expect(AppPaths(harness.directory).libraryJsonFile().existsSync(), isTrue);
  });

  test('HomeLayout pins, unpins, and swaps without compacting gaps', () {
    var home = const HomeLayout()
        .pinning('a', at: 0)
        .pinning('b', at: 2)
        .pinning('c', at: 5);
    expect(home.slots, ['a', null, 'b', null, null, 'c']);
    home = home.unpinning('a');
    expect(home.slots, [null, null, 'b', null, null, 'c']);
    expect(home.contains('b'), isTrue);
    home = home.swapping(2, 3);
    expect(home.slots, [null, null, null, 'b', null, 'c']);
    home = home.moving(3, TraversalDirection.left, 8);
    expect(home.slots, [null, null, 'b', null, null, 'c']);
    expect(HomeLayout.fromJson(home.toJson()), home);
  });

  test('legacy library.json without home copies packed layout into Home', () {
    final state = HomeDeckState.fromJson({
      'version': 1,
      'apps': [
        {
          'id': 'a',
          'displayName': 'A',
          'position': 0,
          'targets': {
            'windows': {
              'platform': 'windows',
              'kind': 'windowsExecutable',
              'value': r'C:\A.exe',
            },
          },
        },
      ],
      'layout': {
        'orderedIds': ['a'],
      },
    });
    expect(state.layout.orderedIds, ['a']);
    expect(state.home.slots, ['a']);
  });

  test('demo seed is off by default and fills only when requested', () async {
    final empty = await createHarness();
    expect(empty.controller.seedDemo, isFalse);
    expect(empty.controller.apps, isEmpty);

    final seeded = await createHarness(seedDemo: true);
    expect(seeded.controller.apps, hasLength(24));
    expect(seeded.controller.apps.first.displayName, 'Arcade Cabinet');
  });
}
