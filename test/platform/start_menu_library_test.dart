import 'package:flutter_test/flutter_test.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/core/models/launch_target.dart';
import 'package:homedeck/core/windows_paths.dart';
import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/start_menu_library.dart';
import 'package:homedeck/platform/windows_adapter.dart';

import '../helpers/fake_platform_adapter.dart';
import '../helpers/test_harness.dart';

void main() {
  final win = WindowsPaths.context;

  group('StartMenuScanner', () {
    test('walks nested Programs folders and prefers resolved .exe', () async {
      final userPrograms = win.join(
        r'C:\Users',
        'Ally',
        'AppData',
        'Roaming',
        'Microsoft',
        'Windows',
        'Start Menu',
        'Programs',
      );
      final games = win.join(userPrograms, 'Games');
      final notepadLnk = win.join(userPrograms, 'Notepad.lnk');
      final portalLnk = win.join(games, 'Portal.lnk');
      final brokenLnk = win.join(userPrograms, 'Missing App.lnk');
      final notepadExe = win.join(r'C:\Windows', 'System32', 'notepad.exe');
      final portalExe = win.join(r'D:\Games', 'Portal', 'portal2.exe');
      final missingExe = win.join(r'C:\Gone', 'missing.exe');

      final io = MemoryWindowsIo(
        existing: {
          notepadLnk,
          portalLnk,
          brokenLnk,
          notepadExe,
          portalExe,
        },
        directories: {
          userPrograms,
          games,
        },
        directoryEntries: {
          userPrograms: [
            'Notepad.lnk',
            'Missing App.lnk',
            'Games',
          ],
          games: [
            'Portal.lnk',
          ],
        },
      );

      final resolutions = <String, ResolvedShortcut>{
        notepadLnk: ResolvedShortcut(targetPath: notepadExe),
        portalLnk: const ResolvedShortcut(
          targetPath: r'D:\Games\Portal\portal2.exe',
          arguments: ['-novid'],
        ),
        brokenLnk: ResolvedShortcut(targetPath: missingExe),
      };

      final scanner = StartMenuScanner(
        io: io,
        programRoots: () => [userPrograms],
        resolveShortcut: (path) async => resolutions[path],
      );

      final found = await scanner.discover();
      expect(found.map((e) => e.displayName).toList(), [
        'Notepad',
        'Portal',
      ]);
      expect(
        found.map((e) => e.target.value).toSet(),
        {notepadExe, portalExe},
      );
      expect(
        found.every((e) => e.target.kind == LaunchTargetKind.windowsExecutable),
        isTrue,
      );
      final portal = found.firstWhere((e) => e.displayName == 'Portal');
      expect(portal.target.arguments, ['-novid']);
    });

    test('keeps .lnk when resolve is empty; dedupes by target across roots',
        () async {
      final user = win.join(r'C:\Users', 'A', 'Programs');
      final allUsers = win.join(r'C:\ProgramData', 'Programs');
      final userLnk = win.join(user, 'Calc.lnk');
      final sharedLnk = win.join(allUsers, 'Calc.lnk');
      final unresolved = win.join(user, 'Store App.lnk');
      final calcExe = win.join(r'C:\Windows', 'System32', 'calc.exe');

      final io = MemoryWindowsIo(
        existing: {userLnk, sharedLnk, unresolved, calcExe},
        directories: {user, allUsers},
        directoryEntries: {
          user: ['Calc.lnk', 'Store App.lnk'],
          allUsers: ['Calc.lnk'],
        },
      );

      final scanner = StartMenuScanner(
        io: io,
        programRoots: () => [user, allUsers],
        resolveShortcut: (path) async {
          if (path == userLnk || path == sharedLnk) {
            return ResolvedShortcut(targetPath: calcExe);
          }
          return null;
        },
      );

      final found = await scanner.discover();
      expect(found, hasLength(2));
      expect(
        found.map((e) => e.displayName).toSet(),
        {'Calc', 'Store App'},
      );
      final calc = found.firstWhere((e) => e.displayName == 'Calc');
      expect(calc.target.kind, LaunchTargetKind.windowsExecutable);
      expect(calc.target.value, calcExe);
      final store = found.firstWhere((e) => e.displayName == 'Store App');
      expect(store.target.kind, LaunchTargetKind.windowsShortcut);
      expect(store.target.value, unresolved);
    });

    test('emits windowsUri when shortcut resolves to a protocol URI', () async {
      final root = win.join(r'C:\StartMenu');
      final lnk = win.join(root, 'Steam.lnk');
      final io = MemoryWindowsIo(
        existing: {lnk},
        directories: {root},
        directoryEntries: {
          root: ['Steam.lnk'],
        },
      );
      final scanner = StartMenuScanner(
        io: io,
        programRoots: () => [root],
        resolveShortcut: (_) async => const ResolvedShortcut(
          targetPath: 'steam://open/games',
        ),
      );
      final found = await scanner.discover();
      expect(found, hasLength(1));
      expect(found.single.target.kind, LaunchTargetKind.windowsUri);
      expect(found.single.target.value, 'steam://open/games');
    });

    test('WindowsAdapter.discoverStartMenu uses injected scanner', () async {
      final io = MemoryWindowsIo();
      final scanner = StartMenuScanner(
        io: io,
        programRoots: () => const [],
        resolveShortcut: (_) async => null,
      );
      final adapter = WindowsAdapter(
        io: io,
        startMenuScanner: scanner,
        filePicker: ({required label, required extensions}) async => null,
      );
      expect(await adapter.discoverStartMenu(), isEmpty);
      expect(await adapter.discover(), isEmpty);
    });
  });

  group('LibraryController.importStartMenu', () {
    test('adds new Start Menu targets and skips duplicates on re-import',
        () async {
      final harness = await createHarness(
        adapter: FakePlatformAdapter(
          discoverStartMenuResult: [
            DiscoveredApp(
              displayName: 'Notepad',
              target: LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsExecutable,
                value: win.join(r'C:\Windows', 'notepad.exe'),
              ),
            ),
            DiscoveredApp(
              displayName: 'Paint',
              target: LaunchTarget(
                platform: AppPlatform.windows,
                kind: LaunchTargetKind.windowsShortcut,
                value: win.join(r'C:\StartMenu', 'Paint.lnk'),
              ),
            ),
          ],
        ),
      );

      final first = await harness.controller.importStartMenu();
      expect(first, 2);
      expect(harness.controller.apps, hasLength(2));
      expect(
        harness.controller.home.contains(harness.controller.apps.first.id),
        isFalse,
      );

      final second = await harness.controller.importStartMenu();
      expect(second, 0);
      expect(harness.controller.apps, hasLength(2));
    });
  });
}
