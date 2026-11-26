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

- **UI** (`lib/ui`) renders the living-room home screen (paged Home, platform
  folders, folder hero, search). Widgets talk to `LibraryController`,
  `WindowModeController`, `GamepadSource`, `DeviceStatus`, and
  `MenuMusicController`. They never import a concrete platform adapter.
- **Core** (`lib/core`) owns the library model, JSON persistence under
  `path_provider`'s `getApplicationSupportDirectory()`, and the icon cache.
  HomeDeck-owned files are referenced with **relative** paths. User-selected
  launch locations stay device-local.
- **Platform** (`lib/platform`) discovers Steam installs, Start Menu Programs
  shortcuts, and configured ROM folders on Windows, resolves icons, validates
  targets, and launches. On Windows, the runner MethodChannel extracts PE /
  `.lnk` icons (Dart FFI secondary) into `IconCache`; generated tiles on
  failure. `selectPlatformAdapter()` is the single switch that returns the
  adapter for this process.

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
launch). Windows Steam discovery is implemented: `WindowsAdapter.discover()`
finds Steam via registry / common `ProgramFiles` candidates (optional
`HOMEDECK_STEAM_ROOT` fixture), reads `steamapps/libraryfolders.vdf` and
`appmanifest_*.acf`, and emits `DiscoveredApp` rows with
`steam://rungameid/{appid}`. Settings → Scan Steam library and bare keyboard
**S** (runner `WH_KEYBOARD_LL` → `WM_HOMEDECK_SCAN_STEAM` → Dart `scanSteam`)
both call `LibraryController.importDiscovered` (Library only; Home pins
unchanged). Start Menu Programs discovery walks
`%APPDATA%\Microsoft\Windows\Start Menu\Programs` and
`%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs` (optional
`HOMEDECK_START_MENU_ROOT` fixture), resolves `.lnk` via runner
`resolveShortcut` (IShellLink GetPath), and emits
`windowsExecutable` / `windowsUri` / `windowsShortcut` targets.
Settings → Scan Start Menu and bare **P** (`WM_HOMEDECK_SCAN_START_MENU` →
Dart `scanStartMenu`) call `LibraryController.importStartMenu` (same
discover → import path; no Home pins). Manual Add (**A** / Open) stays
available. Pinning a focused Library tile to Home uses
`LibraryController.pinToHome`: humans use Menu / Details → Add to Home;
Ally / harness uses bare **H** (`WM_HOMEDECK_PIN_HOME` → Dart
`pinFocusedToHome`) because the Add to Home control is not UIA-reachable.
Unpin / Library remove uses `unpinFromHome` / pending confirm → `remove`:
humans use Menu / Details; Ally uses bare **Delete** / **Backspace**
(`WM_HOMEDECK_REMOVE` → Dart `removeFocused`). While Library remove confirm
is pending, Enter posts `WM_HOMEDECK_CONFIRM` (not ShellExecute) until
dismiss/confirm. ROM-folder scanning walks a Settings-persisted folder (or
`HOMEDECK_ROM_ROOT`) for common extensions and emits `emulated` tiles with
`{rom}` argsTemplate. Optional `HOMEDECK_EMULATOR` or a single obvious
library emulator `.exe` fills the emulator path; otherwise the path is left
empty so Manual Add / edit can finish it. Settings → Scan ROM folder and bare
**R** (`WM_HOMEDECK_SCAN_ROMS` → Dart `scanRoms`) call
`LibraryController.importRoms`. Epic Games discovery reads EpicGamesLauncher
`*.item` manifests under `%ProgramData%\Epic\…\Manifests` (registry
`AppDataPath`, optional `HOMEDECK_EPIC_ROOT` fixture), prefers
`com.epicgames.launcher://apps/…` launch URIs (else resolved `.exe`), and
does not invent games-only filtering. Settings → Scan Epic Games and bare
**E** (`WM_HOMEDECK_SCAN_EPIC` → Dart `scanEpic`) call
`LibraryController.importEpic` (Library only; no Home pins; re-scan skips
duplicate targets). GOG Galaxy discovery walks Galaxy / `GOG Games` roots
(registry client + `GOG.com\Games\{id}\path`, optional `HOMEDECK_GOG_ROOT`)
for `goggame-*.info`, prefers `goggalaxy://openGameView/{gameId}` (else
primary playTask `.exe`), and does not invent games-only filtering.
Settings → Scan GOG and bare **G** (`WM_HOMEDECK_SCAN_GOG` → Dart
`scanGog`) call `LibraryController.importGog` (Library only; no Home pins;
re-scan skips duplicate targets). Ubisoft Connect discovery reads
`Ubisoft\Launcher\Installs\{id}\InstallDir` (optional
`HOMEDECK_UBISOFT_ROOT` fixture with `ubisoftgame-*.info`), prefers
`uplay://launch/{gameId}/0` (else resolved `.exe`), and does not invent
games-only filtering. Settings → Scan Ubisoft Connect and bare **U**
(`WM_HOMEDECK_SCAN_UBISOFT` → Dart `scanUbisoft`) call
`LibraryController.importUbisoft` (Library only; no Home pins; re-scan
skips duplicate targets). EA App / Origin discovery reads
`__Installer\installerdata.xml` under EA Games / Origin Games roots
(registry `Origin Games\{id}`, optional `HOMEDECK_EA_ROOT` fixture),
prefers `origin://launchgame/{offerId}` (else resolved `.exe`), and does
not invent games-only filtering. Settings → Scan EA App and bare **O**
(`WM_HOMEDECK_SCAN_EA` → Dart `scanEa`) call `LibraryController.importEa`
(Library only; no Home pins; re-scan skips duplicate targets). Battle.net
discovery reads Agent `product.db` (and Uninstall `--uid=` entries;
optional `HOMEDECK_BATTLENET_ROOT` fixture with `battlenetgame-*.info` or
`product.db`), prefers `battlenet://{productCode}/` (else resolved
`.exe`), and does not invent games-only filtering (Agent/client component
uids only are skipped). Settings → Scan Battle.net and bare **N**
(`WM_HOMEDECK_SCAN_BATTLENET` → Dart `scanBattlenet`) call
`LibraryController.importBattlenet` (Library only; no Home pins; re-scan
skips duplicate targets). Xbox / Microsoft Store / Game Pass PC discovery
reads GamingRoot / `XboxGames` / `ModifiableWindowsApps` (and optional
`HOMEDECK_XBOX_ROOT` fixture with `xboxgame-*.info` or
`MicrosoftGame.config`), prefers `msxbox:` / `xbox:` /
`ms-windows-store:` when a product id is known (else AppX AUMID
`shell:AppsFolder\{PFN}!{AppId}`, else resolved `.exe`), and does not
invent games-only filtering. WindowsApps ACL and UWP/Game Pass launch
limits are documented honestly — URI/AUMID is best-effort. Settings →
Scan Xbox / Microsoft Store and bare **W** (`WM_HOMEDECK_SCAN_XBOX` →
Dart `scanXbox`) call `LibraryController.importXbox` (Library only; no
Home pins; re-scan skips duplicate targets).

`PreferencesRepository` seeds and writes `library.json` in the application
support directory (`%AppData%\Horton Press\HomeDeck\` on Windows), then
re-reads to verify `apps.length` matches the in-memory state so an
empty-file-only result cannot look like a successful add. It also refuses
to overwrite a non-empty on-disk library with an empty `apps[]` (stale
window/audio prefs snapshot). `LibraryController` queues commits and
persists the live `_state` at write time so a prefs write queued before an
add cannot land empty after the add. On Windows, keyboard **A** / empty Add slots one-shot open a classic
`GetOpenFileName` **Open** dialog and pin on confirm (Ally Phase2 expects
FindWindow-able `Open` after SendKeys `a`, then non-empty `apps` with no
sheet Confirm; Menu → Add game keeps the full sheet for URI/emulated).
SendKeys `a` is handled by the runner `WH_KEYBOARD_LL` hook →
`WM_HOMEDECK_ADD` → OFN on the UI thread → Dart `addPickedPath` (Flutter
Shortcuts alone never saw harness `a` @82a5a20). Optional
`HOMEDECK_ADD_PATH` skips the modal. The same hook handles F11 chrome,
Enter→focused launch (with a Dart `launchFocused` fallback when the
mirrored path is empty), bare **E** → `scanEpic`, bare **G** → `scanGog`,
bare **U** → `scanUbisoft`, bare **O** → `scanEa`, bare **N** →
`scanBattlenet`, bare **W** → `scanXbox`, bare **H** →
`pinFocusedToHome`, and bare **Delete** / **Backspace** →
`removeFocused` (Library confirm Enter → `confirmFocused`, not
ShellExecute).
`IconCache` writes PNG tiles under `icons/` in that same tree.
Menu music is ten bundled `.m4a` tracks (`assets/audio/music/`). Playback
starts at a random index, then walks the playlist in order and wraps.
`AudioPrefs` (music on/off + volume + UI clicks) persist in `library.json`.
Windows playback uses `audioplayers`; load failures are silent. Music ducks
when a game launches or the window blurs, and fades back in on focus. Quiet
UI ticks are synthesized in code. Platform folder tiles look for
`assets/branding/platforms/{slug}.png` later; none ship in this pass.

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

Fullscreen and borderless toggling go through `NativeWindowModeController`
(F11 and Settings). On Windows the runner `homedeck/win32` MethodChannel
applies chrome on the real `FlutterWindow` HWND (and native WM_KEYDOWN F11
toggles the same path). Successful Home / Library launch also enters that
chrome when `WindowPrefs.fullscreenOnLaunch` is true (default; Settings
toggle; mirrored to the runner so Ally Enter→ShellExecute does not skip
it). Local `.exe` / `.lnk` launches use `ShellExecuteEx` with
`SEE_MASK_NOCLOSEPROCESS`; a waiter thread posts `WM_HOMEDECK_GAME_EXIT`
when the process ends. If `WindowPrefs.restoreOnExit` is true (default;
Settings “Return to HomeDeck when game exits”; mirrored to the runner),
the runner leaves launch-entered fullscreen and brings the HomeDeck HWND
to the foreground, then notifies Dart (`gameExited`) to unduck music and
persist prefs. Store URIs (`steam://`, Epic, …) are launch-only — no
process wait and no Steam overlay hooks. Dart FFI `WindowsWindowChrome` /
`window_manager` remain fallbacks because 0.7 often never binds the stock
Flutter runner. Widget tests inject `MemoryWindowModeController`.

Gamepad and battery follow the same split: `WindowsXInputGamepad` polls XInput
on Windows; `WindowsBatteryStatus` reads `GetSystemPowerStatus`. Tests inject
`MemoryGamepadSource` and `MemoryDeviceStatus`.
