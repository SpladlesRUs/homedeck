import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/models/tile_layout.dart';
import 'package:homedeck/core/preferences_repository.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  test('TileLayout reorders and serializes', () {
    const layout = TileLayout(orderedIds: ['a', 'b', 'c', 'd']);
    expect(layout.reordering(0, 2).orderedIds, ['b', 'c', 'a', 'd']);
    expect(
      layout.move('b', TraversalDirection.right, 2).orderedIds,
      ['a', 'c', 'b', 'd'],
    );
    expect(
      TileLayout.fromJson(layout.toJson()),
      layout,
    );
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
    await harness.controller.reorder(0, 2);

    final reloaded = LibraryController(
      adapter: FakePlatformAdapter(),
      preferences: PreferencesRepository(harness.paths),
      icons: IconCache(harness.paths),
    );
    await reloaded.load();

    expect(
      reloaded.apps.map((app) => app.displayName).toList(),
      ['Two', 'Three', 'One'],
    );
    expect(reloaded.state.layout.orderedIds, harness.controller.state.layout.orderedIds);
    expect(
      AppPaths(harness.directory).libraryJsonFile().existsSync(),
      isTrue,
    );
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
