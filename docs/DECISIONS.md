# HomeDeck decisions (milestone 1)

## Open product questions

These stay unresolved on purpose. The data model is not narrowed around either
answer.

1. **Library scope.** Is HomeDeck limited to games and emulators, or does it
   include general applications? Records already support an optional `category`
   and a free-form display name. Milestone 1 does not filter the library.
2. **Manual add vs discovery.** Manual Add remains the primary path (native
   `.exe` / `.lnk` / store URI, or emulator + ROM + `{rom}` args). Windows
   Steam library scan feeds Library via `PlatformAdapter.discover()` →
   `LibraryController.importDiscovered`. Humans use Settings → Scan Steam;
   Ally Phase2 uses bare **S** (WH_KEYBOARD_LL → `WM_HOMEDECK_SCAN_STEAM` →
   Dart `scanSteam`, same as the Settings button — no Settings UIA). Optional
   `HOMEDECK_STEAM_ROOT` points the scanner at a fixture Steam tree. Start Menu
   Programs scan uses `discoverStartMenu()` → `importStartMenu` (same import
   path). Humans use Settings → Scan Start Menu; Ally uses bare **P**
   (`WM_HOMEDECK_SCAN_START_MENU` → `scanStartMenu`). Optional
   `HOMEDECK_START_MENU_ROOT` points at a fixture Programs tree. Pinning a
   focused Library tile to Home: humans use Menu / Details → Add to Home;
   Ally uses bare **H** (`WM_HOMEDECK_PIN_HOME` → `pinFocusedToHome`, same
   `LibraryController.pinToHome` — menu UIA is not required). Unpin / Library
   remove: humans use Menu / Details; Ally uses bare **Delete** / **Backspace**
   (`WM_HOMEDECK_REMOVE` → `removeFocused`, same `_requestRemove` — menu UIA
   is not required). Library confirm Enter is `WM_HOMEDECK_CONFIRM` (not
   ShellExecute). ROM-folder discovery uses `discoverRoms()` → `importRoms`.
   Humans use Settings → Choose ROM folder / Scan ROM folder; Ally uses bare
   **R** (`WM_HOMEDECK_SCAN_ROMS` → `scanRoms`). Optional `HOMEDECK_ROM_ROOT` /
   `HOMEDECK_EMULATOR` fixture the folder and emulator. Epic Games scan uses
   `discoverEpic()` → `importEpic`. Humans use Settings → Scan Epic Games;
   Ally uses bare **E** (`WM_HOMEDECK_SCAN_EPIC` → `scanEpic`). Optional
   `HOMEDECK_EPIC_ROOT` points at a fixture Manifests / Data tree. GOG Galaxy
   scan uses `discoverGog()` → `importGog`. Humans use Settings → Scan GOG;
   Ally uses bare **G** (`WM_HOMEDECK_SCAN_GOG` → `scanGog`). Optional
   `HOMEDECK_GOG_ROOT` points at a fixture Games / install tree. Games-only
   filtering of Steam tools/redistributables, Start Menu entries, Epic
   manifests, or GOG info files is left open with library scope (Epic skips
   incomplete installs only).

## Official app icon

Tre supplied `assets/branding/homedeck-icon.png` (1254×1254). That file is stored
unaltered. Windows `windows/runner/resources/app_icon.ico` is generated from it
with 16, 24, 32, 48, 64, 128, and 256 px layers for the window and taskbar
(via `IDI_APP_ICON` in the runner). The in-app header, settings/about, and
README use the same PNG.

## Windows icon extraction

`WindowsAdapter.resolveIcon` extracts icons on Windows primarily through the
runner MethodChannel (`homedeck/win32` → `extractIcon`): C++ resolves `.lnk`
targets via `IShellLinkW`, pulls PE/Shell icons (`PrivateExtractIconsW` /
`ExtractIconExW` / `SHGetFileInfoW`), and encodes PNG with WIC. A Dart FFI
path remains as a secondary fallback. Bytes are written with sync IO into
`icons/<id>.png` (relative `iconRef`) — the same [IconCache] format as
generated tiles.

Ally M2 icon add (through 1676362): `_homedeck_ready.png` PASS but
**zero** `icons/<id>.png`; `apps=[]`; harness **`Open dialog not found`**.
Root causes stacked: (1) Phase2 never Confirms the in-app Add sheet —
Windows empty-slot / Dart `A` still one-shot `addFromPicker`. (2)
`file_selector` IFileDialog is not FindWindow-able. (3) SendKeys `a`
often never reaches Flutter Shortcuts, so MethodChannel `pickOpenFile`
never ran and classic OFN never appeared. Fix: runner `WH_KEYBOARD_LL`
on `A` posts `WM_HOMEDECK_ADD` → UI-thread `GetOpenFileNameW` with
**window class `#32770`**, **window title exactly `Open`** (OK button
label only is `Add to HomeDeck`; title is force-set in `CDN_INITDONE`),
then `addPickedPath` → Dart `addRecord` + `icons/<id>.png`. Optional
`HOMEDECK_ADD_PATH` bypasses the modal. Ally Phase2 Open wait (do not change harness):
`Wait-WindowTitle -Title 'Open' -TimeoutSec 8` with exact
`(Get-WindowTitle $h) -eq 'Open'` (visible windows; no class filter).
Dialog title is forced to exact `Open` on WM_INITDIALOG and CDN_INITDONE;
OK button may still read `Add to HomeDeck`. Ready seed and tile adds share
`IconCache.writeBytesSync`. `addFromPicker` refuses success without a
durable tile PNG.

When extraction is unavailable (non-Windows host, store URI, missing file,
or any Win32 failure), the placeholder / generated tile already on disk
remains. Extraction never blocks adding a game.

## Steam Deck validation pending

Linux support must include the Steam Deck as a handheld Linux profile. That
work has not started. Pending before calling Linux "done":

- Display scaling at Deck native resolution and in docked TV modes
- Controller navigation through the existing intent set
- Launching games/apps from SteamOS (desktop entries, Steam, Flatpak)

Do not treat Deck as a separate app.

## Platform limits (milestone 1)

| Area | Status |
| --- | --- |
| Windows `.exe` launch via `Process.start` (detached) | Implemented; **not verified on a real Windows PC in this environment** |
| Windows `.lnk` / store URI launch via `cmd /c start` | Implemented as best-effort; **not verified on real Windows** |
| Restore HomeDeck when local game exits | Implemented for tracked `.exe`/`.lnk` (`ShellExecuteEx` + wait); store URIs best-effort launch only (no Steam overlay / session hooks) |
| Emulator + ROM launch with `{rom}` args | Implemented; **not verified on real Windows** |
| Windows PE / `.lnk` icon extraction | Runner MethodChannel + WIC (Dart FFI fallback); generated tile fallback |
| Steam library scanner (Windows) | Implemented; Settings → Scan Steam library |
| Start Menu Programs scanner (Windows) | Implemented; Settings → Scan Start Menu / bare **P** |
| Pin focused Library tile to Home | Implemented; UI Add to Home / bare **H** |
| Unpin / remove focused tile | Implemented; UI Remove / bare **Delete**/**Backspace** |
| ROM-folder scanner | Implemented; Settings → Scan ROM folder / bare **R** |
| Epic Games scanner (Windows) | Implemented; Settings → Scan Epic Games / bare **E** |
| GOG Galaxy scanner (Windows) | Implemented; Settings → Scan GOG / bare **G** |
| macOS / Android launch | Not implemented |
| Linux / Steam Deck launch | Not implemented |
| Accounts, cloud sync | Out of scope |

## How to run on Windows

Requirements: Flutter stable (3.50.x) with the Windows desktop toolchain
(Visual Studio 2022 with "Desktop development with C++").

```bat
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
```

Release build:

```bat
flutter build windows --release
```

The executable is under `build\windows\x64\runner\Release\homedeck.exe`.

Add an app with the on-screen **Add** tile or keyboard **A**. On Windows, **A**
(and empty Add slots) one-shot open a classic `GetOpenFileName` dialog
(window title **Open**, OK label **Add to HomeDeck**) and persist + pin to
Home immediately — Ally Phase2 SendKeys `a` expects a FindWindow-able
`Open` / `#32770` dialog and checks `library.json` after it closes (it never
Confirms an in-app sheet). Tip `bdd3ba1` failed because `file_selector`'s
`IFileDialog` was not FindWindow-able; tip `82a5a20` still failed because
SendKeys `a` never reached Flutter Shortcuts / MethodChannel `pickOpenFile`,
so classic OFN never ran (`Open dialog not found` → `apps=[]`). The runner
`WH_KEYBOARD_LL` hook now posts `WM_HOMEDECK_ADD` on bare **A** (same path as
F11/Enter), shows OFN on the UI thread, then notifies Dart via
`addPickedPath` (which also lands `icons\<id>.png`). Optional
`HOMEDECK_ADD_PATH` (absolute `.exe` / `.lnk`) bypasses the modal and still
lands a pinned tile — **if Ally sets it, skip the FindWindow Open wait** and
assert `library.json` / Enter only. Emulated / URI add uses Menu → Add game
(sheet). Then press Enter (or click) to launch. Layout is stored in the
application support directory provided by `path_provider` (typically under
`%AppData%`) as `library.json`. Cached icons live next to it in `icons\`
(PE / `.lnk` extract via the runner, with a placeholder PNG guaranteed before
upgrade). `PreferencesRepository` seeds `library.json` on first load and
saves with a flushed direct write (temp copy + final overwrite + apps
round-trip check) under `%AppData%\Horton Press\HomeDeck\`. Empty `apps[]`
writes never clobber a non-empty on-disk library. `LibraryController`
serializes commits and persists the live `_state` at write time. Windows
launches use the runner `homedeck/win32` MethodChannel (`ShellExecuteW`), then
Dart FFI / CreateProcess / `cmd /c start`. Ally Phase2 drives keys with
`WScript.Shell.SendKeys` (not top-level `WM_KEYDOWN`), so the runner installs
a `WH_KEYBOARD_LL` hook for F11 chrome, Enter→focused path, A→classic Open,
S→Steam scan, P→Start Menu scan, R→ROM-folder scan, E→Epic Games scan,
G→GOG Galaxy scan, H→pin focused Library tile to Home, and
Delete/Backspace→unpin / Library remove while HomeDeck is foreground; Dart
mirrors the focused launch target,
handles a native `launchFocused` fallback when the mirror is empty, and
persists native `addPickedPath` results. While Library remove confirm is
pending, Enter is `confirmFocused` (not ShellExecute). Dart FFI FindWindow remains a fallback
for F11 because `window_manager` 0.7 often never binds the stock Flutter
window.

### Ally M4 Start Menu smoke

1. Optional fixture: set `HOMEDECK_START_MENU_ROOT` to a Programs-like tree of
   `.lnk` files (or use the real Start Menu on the Ally box).
2. Launch HomeDeck; bare SendKeys **`p`** (no Settings UIA) runs
   discoverStartMenu → importStartMenu.
3. Open Library → By app; new tiles appear (Other / matching store). Pin one
   with Add to Home; focus it; SendKeys Enter launches.
4. SendKeys **`p`** again: `apps.length` unchanged (no duplicate targets).
5. Bare **`s`** and Manual Add (**`a`**) remain unchanged.

### Ally M5 pin-to-Home smoke

1. Scan or open Library with apps present; focus a Library tile (not a folder).
2. Bare SendKeys **`h`** (no Menu / Add to Home UIA) → `home.slots` gains that
   app id; UI switches to Home with the pinned tile focused and the Enter
   launch mirror refreshed (same `pinToHome` as UI Add to Home).
3. SendKeys Enter launches that app (UIA dock → Home keeps the pin focus —
   does not steal to Now Playing).
4. Spot-check bare **`s`** / **`p`** / **`a`** unchanged.

### Ally M6 ROM-folder smoke

1. Set `HOMEDECK_ROM_ROOT` to a fixture folder with 1–2 fake ROMs (or real if
   present). Optional `HOMEDECK_EMULATOR` points at an emulator `.exe`.
2. Launch HomeDeck; bare SendKeys **`r`** (no Settings UIA) runs
   discoverRoms → importRoms.
3. Open Library → By console / Emulated; new ROM tiles appear. If
   `HOMEDECK_EMULATOR` (or a single obvious library emulator) is set, pin one
   with **`h`** and SendKeys Enter launches. If no emulator is configured,
   tiles still import but Enter shows the existing missing-file / incomplete
   launch error until the user finishes the emulator path via Manual Add /
   edit — that is expected.
4. SendKeys **`r`** again: `apps.length` unchanged (no duplicate ROM paths).
5. Spot-check bare **`s`** / **`p`** / **`h`** / **`a`** unchanged.

### Ally M8 restore-on-exit smoke

1. Fullscreen-on-launch ON (default); pin notepad (or another short-lived
   `.exe`); SendKeys Enter → HomeDeck enters fullscreen.
2. Exit notepad → HomeDeck returns to the foreground and leaves fullscreen
   (windowed chrome). Menu music unducks.
3. Settings → turn OFF “Return to HomeDeck when game exits” → launch notepad
   again, exit → HomeDeck does **not** force restore (stays background /
   launch fullscreen as left).
4. Spot-check F11 and bare **`s`** / **`p`** / **`r`** / **`h`** / **`a`**.
5. Store URI / `steam://` tiles still launch; restore is best-effort only
   (no process wait / Steam overlay hooks) — do not FAIL the smoke if a
   Steam session does not auto-return.

### Ally M9 unpin / Library remove smoke

1. Pin a launchable app (e.g. notepad) to Home; focus it; SendKeys **Delete**
   (or **Backspace**) → tile unpinned (`home.slots` / UI). No Menu UIA.
2. Library: focus a removable tile; **Delete** → confirm overlay; **Enter** →
   app gone from `library.json` / UI (**no** accidental launch).
3. **Escape** on confirm cancels; spot-check F11 and **`s`** / **`p`** /
   **`r`** / **`h`** / **`a`**.

### Ally M10 Epic Games smoke

1. Optional fixture: set `HOMEDECK_EPIC_ROOT` to a folder of 1–2 fake
   `*.item` manifests (or a Data root with `Manifests/`), or use a real Epic
   Games Launcher install on the Ally box.
2. Launch HomeDeck; bare SendKeys **`e`** (no Settings UIA) runs
   discoverEpic → importEpic.
3. Open Library → By app → Epic; new tiles appear. Focus one; bare **`h`**
   pins to Home; SendKeys Enter launches (URI via
   `com.epicgames.launcher://apps/…` when present — best-effort if Epic is
   not installed; else resolved `.exe`).
4. SendKeys **`e`** again: `apps.length` unchanged (no duplicate targets).
5. Spot-check F11 and bare **`s`** / **`p`** / **`r`** / **`h`** / **`a`** /
   Delete.

### Ally M11 GOG Galaxy smoke

1. Optional fixture: set `HOMEDECK_GOG_ROOT` to a Games-like tree of 1–2
   folders each with `goggame-*.info` (or a single install folder), or use a
   real GOG Galaxy install on the Ally box.
2. Launch HomeDeck; bare SendKeys **`g`** (no Settings UIA) runs
   discoverGog → importGog.
3. Open Library → By app → GOG; new tiles appear. Focus one; bare **`h`**
   pins to Home; SendKeys Enter launches (URI via
   `goggalaxy://openGameView/…` when present — best-effort if Galaxy is not
   installed; else resolved `.exe`).
4. SendKeys **`g`** again: `apps.length` unchanged (no duplicate targets).
5. Spot-check F11 and bare **`s`** / **`p`** / **`r`** / **`e`** / **`h`** /
   **`a`** / Delete.

Keyboard:

- Arrow keys move focus
- Enter launches (Add sheet also handles Enter / A via `LaunchFocusedIntent`;
  Library remove confirm uses Enter → `confirmFocused`, not ShellExecute)
- Delete / Backspace unpins from Home; in Library it asks to remove the game
  (Ally: `WM_HOMEDECK_REMOVE` — same as UI Remove; menu UIA not required)
- Esc dismisses overlays
- M enters rearrange mode (arrows swap tiles; drag also works)
- S scans Steam library into Library (no Home pins)
- P scans Start Menu Programs into Library (no Home pins)
- R scans the configured ROM folder into Library as emulated tiles (no Home pins)
- E scans Epic Games Launcher installs into Library (no Home pins)
- G scans GOG Galaxy installs into Library (no Home pins)
- H pins the focused Library record onto Home (same as UI Add to Home)
- F11 toggles fullscreen
- Enter / launchFocused enters fullscreen when Settings “Fullscreen on launch”
  is ON (default); Esc / F11 still exit
- When a tracked local `.exe`/`.lnk` exits and Settings “Return to HomeDeck
  when game exits” is ON (default), HomeDeck leaves launch fullscreen and
  comes to the foreground (store `steam://` URIs are not waited on)
- Ctrl+, opens the settings stub

Home is a WiiSU-style paged desktop of pinned shortcuts only — no platform
folders, no By console / By app chips. Page 1 has a large now-playing widget
plus a 5×3 pin grid; later pages are 7×3 with neighbor peeks. Empty slots stay
empty; rearrange with Menu > Move, then D-pad, A to drop. Library is its own
full-screen dock tab (the grid icon), not a sheet over Home: a 5×3 grid of
console or store folders (By console / By app). A opens a platform; B goes
back to the platform grid and stays in Library. LB/RB switch tabs from any
Library level. Opening a folder shows a 3-column game grid and a full-bleed
hero that crossfades after 350 ms. Gamepad X switches grouping only while
already on Library. The only link between the two is Add to Home / Remove
from Home on a Library game. Unpinning from Home never deletes the library
entry. Demo tiles are seeded only with
`--dart-define=HOMEDECK_SEED_DEMO=true` (debug/test); release defaults stay
empty.

Menu music is a ten-track instrumental playlist (Suno Pro, commercial use OK).
On startup a random track starts, then the list plays in order and wraps.
Default volume is modest (0.35) with a fade-in. Launching a game or losing
window focus ducks/pauses; focus fades music back in; exit fades out. Settings
has Music on/off, a volume slider, and a UI-clicks toggle. Clicks are short
code-generated ticks (move/select/back/page), never Suno SFX. Y opens global
search. B is Back only.

Gamepad input on Windows polls XInput directly (D-pad, A, B, LB, RB, Start,
Back) so buttons still work when Flutter does not deliver gamepad keys. Keyboard
arrows / Enter / Esc remain wired through Shortcuts. Battery uses
GetSystemPowerStatus and hides itself when there is no battery.
