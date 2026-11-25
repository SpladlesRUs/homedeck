import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/icon_cache.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/platform/windows_adapter.dart';
import 'package:homedeck/platform/windows_icon_extractor.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

class _RecordingExtractor implements WindowsIconExtractor {
  _RecordingExtractor(this.bytesByPath);

  final Map<String, Uint8List?> bytesByPath;
  final calls = <String>[];

  @override
  Future<Uint8List?> extractPng(String path) async {
    calls.add(path);
    if (bytesByPath.containsKey(path)) {
      return bytesByPath[path];
    }
    return null;
  }
}

class _ThrowingExtractor implements WindowsIconExtractor {
  @override
  Future<Uint8List?> extractPng(String path) async {
    throw StateError('extractor boom');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late IconCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('homedeck_icon_');
    cache = IconCache(AppPaths(tempDir));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('resolveIcon upgrades generated tile with extracted PNG for .exe',
      () async {
    final exe = p.windows.join(r'C:\Games', 'Star Pilot.exe');
    final extractor = _RecordingExtractor({exe: fakePng});
    final adapter = WindowsAdapter(
      io: MemoryWindowsIo(existing: {exe}),
      filePicker: ({required label, required extensions}) async => null,
      iconExtractor: extractor,
    );

    final ref = await adapter.resolveIcon(
      target: windowsTarget(exe),
      cache: cache,
      appId: 'app-exe',
      displayName: 'Star Pilot',
    );

    expect(ref, p.posix.join('icons', 'app-exe.png'));
    expect(extractor.calls, [exe]);
    final file = cache.absoluteFile(ref)!;
    expect(file.existsSync(), isTrue);
    expect(await file.readAsBytes(), fakePng);
  });

  test('resolveIcon upgrades generated tile with extracted PNG for .lnk',
      () async {
    final lnk = p.windows.join(r'C:\Games', 'Star Pilot.lnk');
    final extractor = _RecordingExtractor({lnk: fakePng});
    final adapter = WindowsAdapter(
      io: MemoryWindowsIo(existing: {lnk}),
      filePicker: ({required label, required extensions}) async => null,
      iconExtractor: extractor,
    );

    final ref = await adapter.resolveIcon(
      target: windowsTarget(lnk),
      cache: cache,
      appId: 'app-lnk',
      displayName: 'Star Pilot',
    );

    expect(ref, p.posix.join('icons', 'app-lnk.png'));
    expect(extractor.calls, [lnk]);
    expect(await cache.absoluteFile(ref)!.readAsBytes(), fakePng);
  });

  test('resolveIcon writes generated art before extract (even when extract null)',
      () async {
    final exe = p.windows.join(r'C:\Games', 'Missing Icon.exe');
    final extractor = _RecordingExtractor({exe: null});
    final adapter = WindowsAdapter(
      io: MemoryWindowsIo(existing: {exe}),
      filePicker: ({required label, required extensions}) async => null,
      iconExtractor: extractor,
    );

    final ref = await adapter.resolveIcon(
      target: windowsTarget(exe),
      cache: cache,
      appId: 'app-fallback',
      displayName: 'Missing Icon',
    );

    expect(ref, p.posix.join('icons', 'app-fallback.png'));
    expect(extractor.calls, [exe]);
    final file = File(p.join(tempDir.path, 'icons', 'app-fallback.png'));
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(64));
    final bytes = await file.readAsBytes();
    expect(bytes, isNot(equals(fakePng)));
    // PNG magic
    expect(bytes.sublist(0, 8), fakePng.sublist(0, 8));
  });

  test('resolveIcon skips extract for missing paths but still writes generated art',
      () async {
    final missing = p.windows.join(r'C:\Games', 'Gone.exe');
    final extractor = _RecordingExtractor({});
    final adapter = WindowsAdapter(
      io: MemoryWindowsIo(),
      filePicker: ({required label, required extensions}) async => null,
      iconExtractor: extractor,
    );

    final ref = await adapter.resolveIcon(
      target: windowsTarget(missing),
      cache: cache,
      appId: 'app-missing',
      displayName: 'Gone',
    );

    expect(extractor.calls, isEmpty);
    expect(ref, p.posix.join('icons', 'app-missing.png'));
    expect(File(p.join(tempDir.path, 'icons', 'app-missing.png')).existsSync(),
        isTrue);
  });

  test('resolveIcon keeps generated tile when extractor throws', () async {
    final boom = p.windows.join(r'C:\Games', 'Boom.exe');
    final adapter = WindowsAdapter(
      io: MemoryWindowsIo(existing: {boom}),
      filePicker: ({required label, required extensions}) async => null,
      iconExtractor: _ThrowingExtractor(),
    );

    final ref = await adapter.resolveIcon(
      target: windowsTarget(boom),
      cache: cache,
      appId: 'app-throw',
      displayName: 'Boom',
    );

    expect(ref, p.posix.join('icons', 'app-throw.png'));
    expect(cache.absoluteFile(ref)!.existsSync(), isTrue);
    expect(cache.absoluteFile(ref)!.lengthSync(), greaterThan(64));
  });

  test('resolveIcon skips extraction for store URIs but writes generated art',
      () async {
    final extractor = _RecordingExtractor({});
    final adapter = WindowsAdapter(
      io: MemoryWindowsIo(),
      filePicker: ({required label, required extensions}) async => null,
      iconExtractor: extractor,
    );

    final ref = await adapter.resolveIcon(
      target: const LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsUri,
        value: 'steam://rungameid/440',
      ),
      cache: cache,
      appId: 'app-uri',
      displayName: 'Team Fortress',
    );

    expect(extractor.calls, isEmpty);
    expect(ref, p.posix.join('icons', 'app-uri.png'));
    expect(cache.absoluteFile(ref)!.existsSync(), isTrue);
  });

  test('resolveIcon asks extractor for emulator .exe on emulated tiles',
      () async {
    final emulator = p.windows.join(r'C:\Emulators', 'retro.exe');
    final extractor = _RecordingExtractor({emulator: fakePng});
    final adapter = WindowsAdapter(
      io: MemoryWindowsIo(existing: {emulator}),
      filePicker: ({required label, required extensions}) async => null,
      iconExtractor: extractor,
    );

    final ref = await adapter.resolveIcon(
      target: LaunchTarget(
        platform: AppPlatform.windows,
        kind: LaunchTargetKind.windowsEmulated,
        value: emulator,
        romPath: p.windows.join(r'C:\Roms', 'game.nes'),
      ),
      cache: cache,
      appId: 'app-emu',
      displayName: 'Retro Game',
    );

    expect(extractor.calls, [emulator]);
    expect(await cache.absoluteFile(ref)!.readAsBytes(), fakePng);
  });

  test('IconCache.writePng flushes a durable non-empty file under icons/',
      () async {
    final ref = await cache.writePng('sync-icon', fakePng);
    final file = File(p.join(tempDir.path, 'icons', 'sync-icon.png'));
    expect(ref, p.posix.join('icons', 'sync-icon.png'));
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), fakePng.length);
    expect(cache.absoluteFile(ref)!.path, file.path);
    expect(cache.absoluteFile('icons/missing.png'), isNull);
  });

  test('ensureReady seeds a probe PNG Ally can watch under icons/', () async {
    await cache.ensureReady();
    final probe = File(p.join(tempDir.path, 'icons', IconCache.readyProbeName));
    expect(probe.existsSync(), isTrue);
    expect(probe.lengthSync(), greaterThan(0));
  });

  test('writePng lands beside the ready probe using the same icons-dir join',
      () async {
    await cache.ensureReady();
    final ref = await cache.writePng('tile-abc', fakePng);
    expect(ref, p.posix.join('icons', 'tile-abc.png'));
    final dir = Directory(p.join(tempDir.path, 'icons'));
    final names = dir
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .toSet();
    expect(names, contains(IconCache.readyProbeName));
    expect(names, contains('tile-abc.png'));
    expect(
      File(p.join(tempDir.path, 'icons', 'tile-abc.png')).readAsBytesSync(),
      fakePng,
    );
  });
}
