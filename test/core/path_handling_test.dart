import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/app_paths.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/windows_adapter.dart';
import 'package:path/path.dart' as p;

import '../helpers/test_harness.dart';

void main() {
  test('WindowsPaths keeps spaces and Unicode intact', () {
    final spaced = p.windows.join(
      'Games',
      'My Collection',
      'Cool Game.exe',
    );
    expect(WindowsPaths.basenameWithoutExtension(spaced), 'Cool Game');
    expect(WindowsPaths.isExecutable(spaced), isTrue);
    expect(spaced.contains(' '), isTrue);

    final unicode = p.windows.join(
      'Games',
      'フォトデッキ',
      'アプリ.exe',
    );
    expect(WindowsPaths.basenameWithoutExtension(unicode), 'アプリ');
    expect(unicode.contains('フォトデッキ'), isTrue);
    expect(WindowsPaths.extension(unicode), '.exe');
  });

  test('looksLikeVolumePath is true only for Windows drives and UNC shares', () {
    expect(WindowsPaths.looksLikeVolumePath(r'C:\Games\Star Pilot.exe'), isTrue);
    expect(WindowsPaths.looksLikeVolumePath(r'D:\Apps\tool.exe'), isTrue);
    expect(
      WindowsPaths.looksLikeVolumePath(r'\\unavailable-volume\HomeDeck\Vanished.exe'),
      isTrue,
    );
    expect(
      WindowsPaths.looksLikeVolumePath('/home/user/My Games/Star Pilot.exe'),
      isFalse,
    );
    expect(
      WindowsPaths.looksLikeVolumePath(p.join('home', 'My Games', 'app.exe')),
      isFalse,
    );
  });

  test('AppPaths rejects absolute icon refs and joins with package:path', () async {
    final dir = await Directory.systemTemp.createTemp('homedeck_paths_');
    addTearDown(() => dir.delete(recursive: true));
    final paths = AppPaths(dir);
    final relative = paths.iconRelativeRef('abc');
    expect(p.isRelative(relative), isTrue);
    expect(relative, isNot(contains(r'\')));
    expect(p.posix.split(relative), ['icons', 'abc.png']);
    expect(
      () => paths.resolveOwned(p.join(p.separator, 'etc', 'passwd')),
      throwsArgumentError,
    );
    expect(
      () => paths.resolveOwned(p.join('..', 'outside.png')),
      throwsArgumentError,
    );
  });

  test('missing files, spaces, Unicode, and removed volumes validate clearly', () async {
    final spaced = p.windows.join(
      r'\\library\share',
      'My Games',
      'Star Pilot.exe',
    );
    final unicode = p.windows.join(
      r'\\library\share',
      'ユニコード',
      'ゲーム.exe',
    );
    final missing = p.windows.join(
      r'\\library\share',
      'Gone',
      'Missing.exe',
    );
    final removed = p.windows.join(
      r'\\unavailable-volume\HomeDeck',
      'Vanished.exe',
    );
    final locked = p.windows.join(
      r'\\library\share',
      'Locked.exe',
    );

    final io = MemoryWindowsIo(
      existing: {spaced, unicode, locked},
      readyVolumes: {
        WindowsPaths.rootPrefix(spaced),
        WindowsPaths.rootPrefix(unicode),
        WindowsPaths.rootPrefix(locked),
      },
      permissionDenied: {locked},
    );
    final adapter = WindowsAdapter(
      io: io,
      filePicker: ({required label, required extensions}) async => null,
    );

    expect(await adapter.validateTarget(windowsTarget(spaced)), isNull);
    expect(await adapter.validateTarget(windowsTarget(unicode)), isNull);

    final missingFailure = await adapter.validateTarget(windowsTarget(missing));
    expect(missingFailure?.kind, LaunchFailureKind.missingFile);

    final driveFailure = await adapter.validateTarget(windowsTarget(removed));
    expect(driveFailure?.kind, LaunchFailureKind.removedDrive);

    final denied = await adapter.validateTarget(windowsTarget(locked));
    expect(denied?.kind, LaunchFailureKind.permissionDenied);
  });

  test('Process.start arguments keep spaces; shortcuts use detached cmd start', () async {
    final io = MemoryWindowsIo(
      existing: {
        p.windows.join('Apps', 'My Game.exe'),
        p.windows.join('Apps', 'Link.lnk'),
      },
      readyVolumes: const {},
    );
    // These paths are relative Windows paths without a volume, so volume
    // checks are skipped and existence is whatever MemoryWindowsIo reports.
    final adapter = WindowsAdapter(
      io: io,
      filePicker: ({required label, required extensions}) async => null,
    );
    final exe = windowsTarget(p.windows.join('Apps', 'My Game.exe'));
    final lnk = windowsTarget(p.windows.join('Apps', 'Link.lnk'));

    expect(await adapter.launch(exe), isA<LaunchSuccess>());
    expect(await adapter.launch(lnk), isA<LaunchSuccess>());
    expect(io.launches, hasLength(2));
    expect(io.launches[0].executable, exe.value);
    expect(io.launches[0].shortcut, isFalse);
    expect(io.launches[1].shortcut, isTrue);
  });
}
