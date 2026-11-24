import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/app.dart';
import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/device_status.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/preferences_repository.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/platform/windows_io.dart';
import 'package:homedeck/ui/home_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'fake_platform_adapter.dart';

class SequentialIds {
  SequentialIds([this.prefix = 'app']);

  final String prefix;
  var _n = 0;

  String call() {
    _n += 1;
    return '$prefix-$_n';
  }
}

class MemoryWindowsIo implements WindowsIo {
  MemoryWindowsIo({
    Set<String>? existing,
    Set<String>? readyVolumes,
    this.permissionDenied = const {},
  }) : existing = existing ?? {},
       readyVolumes = readyVolumes ?? {};

  final Set<String> existing;
  final Set<String> readyVolumes;
  final Set<String> permissionDenied;
  final launches = <({String executable, List<String> arguments, bool shortcut})>[];

  @override
  Future<bool> fileExists(String path) async => existing.contains(path);

  @override
  Future<bool> volumeReady(String rootPrefix) async =>
      readyVolumes.contains(rootPrefix);

  @override
  Future<void> checkReadable(String path) async {
    if (permissionDenied.contains(path)) {
      throw const FileSystemException(
        'Access denied',
        null,
        OSError('Access denied', 5),
      );
    }
  }

  @override
  Future<void> startDetached({
    required String executable,
    required List<String> arguments,
    required bool shortcut,
  }) async {
    launches.add((
      executable: executable,
      arguments: arguments,
      shortcut: shortcut,
    ));
  }
}

class Harness {
  Harness({
    required this.directory,
    required this.paths,
    required this.adapter,
    required this.controller,
    required this.windowMode,
    required this.gamepad,
    required this.deviceStatus,
  });

  final Directory directory;
  final AppPaths paths;
  final FakePlatformAdapter adapter;
  final LibraryController controller;
  final MemoryWindowModeController windowMode;
  final MemoryGamepadSource gamepad;
  final MemoryDeviceStatus deviceStatus;
}

Future<Harness> createHarness({
  FakePlatformAdapter? adapter,
  bool seedDemo = false,
}) async {
  final directory = Directory.systemTemp.createTempSync('homedeck_');
  addTearDown(() => _tryDeleteTemp(directory));
  final paths = AppPaths(directory);
  final fake = adapter ?? FakePlatformAdapter();
  final controller = LibraryController(
    adapter: fake,
    preferences: PreferencesRepository(paths),
    icons: IconCache(paths),
    idFactory: SequentialIds().call,
    seedDemo: seedDemo,
  );
  await controller.load();
  return Harness(
    directory: directory,
    paths: paths,
    adapter: fake,
    controller: controller,
    windowMode: MemoryWindowModeController(),
    gamepad: MemoryGamepadSource(),
    deviceStatus: MemoryDeviceStatus(batteryPercent: 100),
  );
}

Future<Harness> createHarnessForWidgets(
  WidgetTester tester, {
  FakePlatformAdapter? adapter,
  bool seedDemo = false,
}) async {
  final harness = await tester.runAsync(
    () => createHarness(adapter: adapter, seedDemo: seedDemo),
  );
  return harness!;
}

Future<void> addSampleAppsForWidgets(
  WidgetTester tester,
  Harness harness, {
  int count = 3,
  LaunchFailure? validation,
}) async {
  await tester.runAsync(
    () => addSampleApps(harness, count: count, validation: validation),
  );
}

Future<void> pumpHomeDeck(WidgetTester tester, Harness harness) async {
  HomeScreen.tickClock = false;
  addTearDown(() => HomeScreen.tickClock = true);
  await tester.pumpWidget(
    HomeDeckApp(
      controller: harness.controller,
      windowMode: harness.windowMode,
      gamepad: harness.gamepad,
      deviceStatus: harness.deviceStatus,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

LaunchTarget windowsTarget(String value, {LaunchTargetKind? kind}) {
  return LaunchTarget(
    platform: AppPlatform.windows,
    kind: kind ??
        (p.windows.extension(value).toLowerCase() == '.lnk'
            ? LaunchTargetKind.windowsShortcut
            : LaunchTargetKind.windowsExecutable),
    value: value,
  );
}

Future<void> addSampleApps(
  Harness harness, {
  int count = 3,
  LaunchFailure? validation,
}) async {
  harness.adapter.validation = validation;
  for (var i = 0; i < count; i++) {
    final name = 'Tile ${i + 1}';
    await harness.controller.addRecord(
      displayName: name,
      target: windowsTarget(p.join(harness.directory.path, '$name.exe')),
    );
  }
}

bool focusOn(WidgetTester tester, Key key) {
  final focus = find.descendant(
    of: find.byKey(key),
    matching: find.byType(Focus),
  );
  return tester.widget<Focus>(focus).focusNode?.hasFocus ?? false;
}

Future<void> _tryDeleteTemp(Directory directory) async {
  for (var attempt = 0; attempt < 8; attempt++) {
    try {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
      return;
    } on FileSystemException {
      await Future<void>.delayed(Duration(milliseconds: 40 * (attempt + 1)));
    }
  }
}

Future<void> sendArrow(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
