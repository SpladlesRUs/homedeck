import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/platform/windows_adapter.dart';
import 'package:homedeck/platform/windows_automation.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_harness.dart';

void main() {
  test('seedHomeDeckAddPath pins exe and persists apps', () async {
    final harness = await createHarness();
    final notepad = p.join(harness.directory.path, 'notepad.exe');
    await File(notepad).writeAsString('x', flush: true);

    final added = await seedHomeDeckAddPath(
      harness.controller,
      pathOverride: notepad,
    );
    expect(added, isNotNull);
    expect(harness.controller.apps, hasLength(1));
    expect(harness.controller.isOnHome(added!.id), isTrue);

    final again = await seedHomeDeckAddPath(
      harness.controller,
      pathOverride: notepad,
    );
    expect(again?.id, added.id);
    expect(harness.controller.apps, hasLength(1));

    final decoded =
        jsonDecode(harness.paths.libraryJsonFile().readAsStringSync()) as Map;
    expect(decoded['apps'] as List, hasLength(1));
  });

  test('pickedLaunchFromPath accepts exe and lnk', () {
    expect(
      WindowsAdapter.pickedLaunchFromPath(r'C:\Windows\System32\notepad.exe')
          ?.displayName,
      'notepad',
    );
    expect(
      WindowsAdapter.pickedLaunchFromPath(r'C:\HomeDeckTest\notepad.lnk')
          ?.displayName,
      'notepad',
    );
    expect(WindowsAdapter.pickedLaunchFromPath(r'C:\nope.txt'), isNull);
    expect(WindowsAdapter.pickedLaunchFromPath(null), isNull);
  });
}
