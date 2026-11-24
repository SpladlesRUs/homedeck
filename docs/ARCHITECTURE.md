# HomeDeck architecture

HomeDeck is a Flutter desktop launcher. Shared UI and library behavior live in
Dart. Operating-system details sit behind a `PlatformAdapter` so Windows can
ship first without painting macOS, Android, or Linux launch logic into widgets.

## Layers

```
lib/ui          Home grid, tiles, focus/selection, settings stub
lib/core        AppRecord, LaunchTarget, TileLayout, preferences, icon cache
lib/platform    PlatformAdapter, WindowsAdapter, selectPlatformAdapter()
```

- **UI** (`lib/ui`) renders the living-room home screen. Widgets talk to
  `LibraryController`, `WindowModeController`, `GamepadSource`, and
  `DeviceStatus`. They never import a concrete platform adapter.
- **Core** (`lib/core`) owns the library model, JSON persistence under
  `path_provider`'s `getApplicationSupportDirectory()`, and the icon cache.
  HomeDeck-owned files are referenced with **relative** paths. User-selected
  launch locations stay device-local.
- **Platform** (`lib/platform`) discovers (later), resolves icons, validates
  targets, and launches. `selectPlatformAdapter()` is the single switch that
  returns the adapter for this process.

Navigation uses Flutter `Shortcuts`, `Actions`, and `FocusTraversal` intents
(`LaunchFocusedIntent`, `DirectionalFocusIntent`, and friends) so a later
gamepad or touch mapping can invoke the same actions.

## Data

`AppRecord` has a stable UUID, display name, relative `iconRef`, position,
optional category/favorite, a `TileKind` (`native` or `emulated`), optional
`console` / `store`, and `Map<AppPlatform, LaunchTarget>`. The **Library** is
every record. **Home** is a separate sparse slot list (`HomeLayout`) of
shortcuts the user pins — empty cells stay empty. Unpinning never deletes
the library entry.

Native Windows targets are a `.exe`, a `.lnk`, or a store URI
(`steam://rungameid/…`, Epic, GOG, Xbox). Emulated targets are an emulator
executable plus a `romPath` and an `argsTemplate` (`{rom}` is replaced at
launch). Steam library and ROM-folder auto-discovery are **not** implemented;
`PlatformAdapter.discover()` is the extension point and currently returns
`[]`. A later scanner should emit `DiscoveredApp` (with `TileKind`) and call
`LibraryController.addRecord` without changing the home widgets.

`PreferencesRepository` writes `library.json` in the application support
directory. `IconCache` writes PNG tiles under `icons/` in that same tree.

All path joins go through `package:path` (`p.join`, `p.windows.*`). The code
does not concatenate separators or hard-code home directories, usernames, or
install folders.

## Adding macOS, Android, and Linux / Steam Deck adapters

1. Implement `PlatformAdapter` in `lib/platform/<os>_adapter.dart`.
2. Keep discovery, icon lookup, validation, and launch **inside** that file.
3. Register it in `selectPlatformAdapter()`:

   ```dart
   if (Platform.isMacOS) return MacosAdapter();
   if (Platform.isAndroid) return AndroidAdapter();
   if (Platform.isLinux) return LinuxAdapter(profile: LinuxProfile.desktop);
   ```

4. Use native identifiers, not filesystem paths copied from Windows:

   | Platform | `LaunchTargetKind` | `value` |
   | --- | --- | --- |
   | Windows | `windowsExecutable` / `windowsShortcut` / `windowsUri` / `windowsEmulated` | Absolute `.exe` / `.lnk`, store URI, or emulator + ROM |
   | macOS | `macosBundleId` | Bundle identifier |
   | Android | `androidPackage` | Application id |
   | Linux | `linuxDesktopEntry` | Desktop file id or argv suitable for that distro |

5. Treat **Steam Deck as a Linux device profile**, not a second architecture.
   When Linux work starts, validate Deck display scaling, controller focus
   traversal (already intent-based), and launch behavior on SteamOS. Do not
   assume a nested desktop session or a particular home path.

Milestone 1 ships the Windows Flutter target only. Linux launch and a Linux
desktop runner are not in this tree.

## Window chrome

Fullscreen and borderless toggling use `window_manager` (F11 and Settings).
`NativeWindowModeController` wraps the plugin so widget tests can inject
`MemoryWindowModeController`.

Gamepad and battery follow the same split: `WindowsXInputGamepad` polls XInput
on Windows; `WindowsBatteryStatus` reads `GetSystemPowerStatus`. Tests inject
`MemoryGamepadSource` and `MemoryDeviceStatus`.
