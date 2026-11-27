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
   `LibraryController.importDiscovered`. Humans use Settings → Scan Steam or
   Library `+` → Rescan Steam;
   Ally Phase2 uses bare **S** (WH_KEYBOARD_LL → `WM_HOMEDECK_SCAN_STEAM` →
   Dart `scanSteam`, same as the Settings button — no Settings UIA). Optional
   `HOMEDECK_STEAM_ROOT` points the scanner at a fixture Steam tree. Start Menu
   Programs scan uses `discoverStartMenu()` → `importStartMenu` (same import
   path). Humans use Settings → Scan Start Menu or Library `+` → Rescan Start
   Menu; Ally uses bare **P** (`WM_HOMEDECK_SCAN_START_MENU` →
   `scanStartMenu`). Optional `HOMEDECK_START_MENU_ROOT` points at a fixture
   Programs tree. Pinning a focused Library tile to Home: humans use Menu /
   Details → Add to Home; Ally uses bare **H** (`WM_HOMEDECK_PIN_HOME` →
   `pinFocusedToHome`, same `LibraryController.pinToHome` — menu UIA is not
   required). Unpin / Library remove: humans use Menu / Details; Ally uses
   bare **Delete** / **Backspace** (`WM_HOMEDECK_REMOVE` → `removeFocused`,
   same `_requestRemove` — menu UIA is not required). Library confirm Enter is
   `WM_HOMEDECK_CONFIRM` (not ShellExecute). ROM-folder discovery uses
   `discoverRoms()` → `importRoms`. Humans use Settings → Choose ROM folder /
   Scan ROM folder or Library `+` → Rescan ROM folder; Ally uses bare **R**
   (`WM_HOMEDECK_SCAN_ROMS` → `scanRoms`). Optional `HOMEDECK_ROM_ROOT` /
   `HOMEDECK_EMULATOR` fixture the folder and emulator. Epic Games scan uses
   `discoverEpic()` → `importEpic`. Humans use Settings → Scan Epic Games or
   Library `+` → Rescan Epic Games; Ally uses bare **E**
   (`WM_HOMEDECK_SCAN_EPIC` → `scanEpic`). Optional `HOMEDECK_EPIC_ROOT`
   points at a fixture Manifests / Data tree. GOG Galaxy scan uses
   `discoverGog()` → `importGog`. Humans use Settings → Scan GOG or Library
   `+` → Rescan GOG; Ally uses bare **G** (`WM_HOMEDECK_SCAN_GOG` →
   `scanGog`). Optional `HOMEDECK_GOG_ROOT` points at a fixture Games /
   install tree. Ubisoft Connect scan uses `discoverUbisoft()` →
   `importUbisoft`. Humans use Settings → Scan Ubisoft Connect or Library
   `+` → Rescan Ubisoft Connect; Ally uses bare **U**
   (`WM_HOMEDECK_SCAN_UBISOFT` → `scanUbisoft`). Optional
   `HOMEDECK_UBISOFT_ROOT` points at a fixture Games / install tree
   (`ubisoftgame-*.info`). EA App / Origin scan uses `discoverEa()` →
   `importEa`. Humans use Settings → Scan EA App or Library `+` → Rescan
   EA App; Ally uses bare **O** (`WM_HOMEDECK_SCAN_EA` → `scanEa`).
   Optional `HOMEDECK_EA_ROOT` points at a fixture Games / install tree
   (`__Installer\installerdata.xml`). Battle.net scan uses
   `discoverBattlenet()` → `importBattlenet`. Humans use Settings → Scan
   Battle.net or Library `+` → Rescan Battle.net; Ally uses bare **N**
   (`WM_HOMEDECK_SCAN_BATTLENET` → `scanBattlenet`). Optional
   `HOMEDECK_BATTLENET_ROOT` points at a fixture Games / Agent
   `product.db` / install tree (`battlenetgame-*.info`). Xbox /
   Microsoft Store / Game Pass PC scan uses `discoverXbox()` →
   `importXbox`. Humans use Settings → Scan Xbox / Microsoft Store or
   Library `+` → Rescan Xbox / Microsoft Store; Ally uses bare **W**
   (`WM_HOMEDECK_SCAN_XBOX` → `scanXbox`). Optional `HOMEDECK_XBOX_ROOT`
   points at a fixture XboxGames / GamingRoot / install tree
   (`xboxgame-*.info` or `MicrosoftGame.config`). Prefer `msxbox:` /
   `xbox:` / `ms-windows-store:` when a product id is known; else AppX
   AUMID (`shell:AppsFolder\{PFN}!{AppId}`); else resolved `.exe`.
   UWP/Game Pass limits: WindowsApps is often ACL-locked; raw `.exe`
   launch frequently fails — URI/AUMID is best-effort. Games-only
   filtering of Steam tools/redistributables, Start Menu entries, Epic
   manifests, GOG info files, Ubisoft installs, EA installs, Battle.net
   installs, or Xbox installs is left open with library scope (Epic skips
   incomplete installs only; Battle.net skips Agent/client component
   uids only).

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
| Ubisoft Connect scanner (Windows) | Implemented; Settings → Scan Ubisoft Connect / bare **U** |
| EA App / Origin scanner (Windows) | Implemented; Settings → Scan EA App / bare **O** |
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
G→GOG Galaxy scan, U→Ubisoft Connect scan, O→EA App / Origin scan,
H→pin focused Library tile to Home, and
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

### Ally M12 Ubisoft Connect smoke

1. Optional fixture: set `HOMEDECK_UBISOFT_ROOT` to a Games-like tree of 1–2
   folders each with `ubisoftgame-*.info` (or a single install folder), or use
   a real Ubisoft Connect install on the Ally box.
2. Launch HomeDeck; bare SendKeys **`u`** (no Settings UIA) runs
   discoverUbisoft → importUbisoft.
3. Open Library → By app → Ubisoft Connect; new tiles appear. Focus one; bare
   **`h`** pins to Home; SendKeys Enter launches (URI via
   `uplay://launch/…` when present — best-effort if Connect is not
   installed; else resolved `.exe`).
4. SendKeys **`u`** again: `apps.length` unchanged (no duplicate targets).
5. Spot-check F11 and bare **`s`** / **`p`** / **`r`** / **`e`** / **`g`** /
   **`h`** / **`a`** / Delete.

### Ally M13 EA App / Origin smoke

1. Optional fixture: set `HOMEDECK_EA_ROOT` to a Games-like tree of 1–2
   folders each with `__Installer\installerdata.xml` (or a single install
   folder), or use a real EA App / Origin install on the Ally box.
2. Launch HomeDeck; bare SendKeys **`o`** (no Settings UIA) runs
   discoverEa → importEa.
3. Open Library → By app → Origin / EA app; new tiles appear. Focus one; bare
   **`h`** pins to Home; SendKeys Enter launches (URI via
   `origin://launchgame/…` when present — best-effort if EA App is not
   installed; else resolved `.exe`).
4. SendKeys **`o`** again: `apps.length` unchanged (no duplicate targets).
5. Spot-check F11 and bare **`s`** / **`p`** / **`r`** / **`e`** / **`g`** /
   **`u`** / **`h`** / **`a`** / Delete.

### Ally M14 Battle.net smoke

1. Optional fixture: set `HOMEDECK_BATTLENET_ROOT` to a Games-like tree of
   1–2 folders each with `battlenetgame-*.info` (or an Agent `product.db`
   / install folder), or use a real Battle.net install on the Ally box.
2. Launch HomeDeck; bare SendKeys **`n`** (no Settings UIA) runs
   discoverBattlenet → importBattlenet.
3. Open Library → By app → Battle.net; new tiles appear. Focus one; bare
   **`h`** pins to Home; SendKeys Enter launches (URI via
   `battlenet://…` when present — best-effort if Battle.net is not
   installed; else resolved `.exe`).
4. SendKeys **`n`** again: `apps.length` unchanged (no duplicate targets).
5. Spot-check F11 and bare **`s`** / **`p`** / **`r`** / **`e`** / **`g`** /
   **`u`** / **`o`** / **`h`** / **`a`** / Delete.

### Ally M15 Xbox / Microsoft Store smoke

1. Optional fixture: set `HOMEDECK_XBOX_ROOT` to an XboxGames-like tree of
   1–2 folders each with `xboxgame-*.info` or `MicrosoftGame.config` (or
   a real Xbox / Game Pass PC install / GamingRoot on the Ally box).
2. Launch HomeDeck; bare SendKeys **`w`** (no Settings UIA) runs
   discoverXbox → importXbox.
3. Open Library → By app → Xbox / Microsoft Store; new tiles appear.
   Focus one; bare **`h`** pins to Home; SendKeys Enter launches (URI via
   `msxbox:` / `xbox:` / `ms-windows-store:` or AUMID when present —
   best-effort for UWP/Game Pass; raw `.exe` often fails).
4. SendKeys **`w`** again: `apps.length` unchanged (no duplicate targets).
5. Spot-check F11 and bare **`s`** / **`p`** / **`r`** / **`e`** / **`g`** /
   **`u`** / **`o`** / **`n`** / **`h`** / **`a`** / Delete.

### Ally M16 animated focus smoke

Visual check (widget tests cover ring presence / scale / spin; Ally confirms
motion on device). Focused Home / Library / folder tiles — including empty
Home slots — use a spinning cyan→cyanDeep→gold gradient ring plus a slight
scale-up (`TileFace`); unfocused tiles stay calm (no ring).

1. Launch HomeDeck; move focus across Home tiles (filled + empty) — focused
   tile shows the animated ring / scale (not a static outline).
2. Library folder: focus games — same focus treatment; folder hero still
   settles / crossfades after ~350 ms.
3. Spot-check Enter launch, Delete / unpin, F11, and bare
   **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** / **`o`** /
   **`n`** / **`w`** / **`h`** / **`a`** unchanged.

### Ally M17 auto-hide tab dock smoke

The bottom tab dock auto-hides after **2.5s** idle on Home and Library root
(and the placeholder tabs). Activity (D-pad / keys / pointer while visible)
resets the timer; it does not unhide a already-hidden dock. LB / RB,
PageUp / PageDown, next/prev-tab intents, dock tab taps, and the bottom
`dock-reveal-hit` strip force the dock visible again (slight slide; no
opacity fade so Ally UIA keeps tab Semantics during the entrance and across
tab switches). A show-epoch cancels in-flight idle hides so force-show /
PageDown cannot be immediately re-hidden. Inside a Library folder the dock
stays on the existing hide + `_dockForced` path (down-edge / LB-RB /
PageUp-PageDown / bottom hit). The first LB/RB or PageUp/PageDown while the
folder dock is down only force-reveals TabDock (stay in folder; Ally UIA
sees 5 tabs again); a second press then exits and advances the tab. Never
skip dock tabs when cycling.

1. On Home: wait idle → dock hides (removed from tree; bottom hit strip remains).
2. SendKeys PageDown or gamepad RB → dock returns; tab advances (Home→Games
   on PageDown / RB; LB wraps Home→Library).
3. Open a Library folder → dock hidden; PageDown / LB/RB / bottom hit
   remounts TabDock while staying in the folder (`_dockForced`).
4. Spot-check Enter, Delete, F11, focus ring, and bare
   **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** / **`o`** /
   **`n`** / **`w`** / **`h`** / **`a`**.

### Ally M18 title-pill page dots smoke

On Home the centered title pill shows WiiSU-style page dots (active page
emphasized) instead of a text title — matching iiSU “title bar off → page
dots in capsule.” Library, open folders, and other tabs keep the focused-item
(or section) name as text. The under-grid page-dot row is removed so the pill
is the primary pager chrome. Pill stays truly centered.

1. Home: title-pill shows page dots; active page matches; change page (dot tap
   or existing pager / edge arrows) updates the active dot.
2. Library / open folder: title-pill shows focused name (text), not dots.
3. Spot-check dock idle hide, focus ring, Enter/Delete, F11, and bare
   **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** / **`o`** /
   **`n`** / **`w`** / **`h`** / **`a`**.

### Ally M19 context-sensitive + menu smoke

Home `+` stays **Customize Home**: Add game, Global Search, Reorder home,
New Collection, Settings, Exit — no Library scan rows. Library (root or
inside a folder) `+` is Library-focused: Add game, Global Search, **Rescan
Steam** / **Rescan Start Menu** / **Rescan ROM folder** (same import paths
as Settings and harness bare **S** / **P** / **R** — keys `menu-scan-steam`
/ `menu-scan-start-menu` / `menu-scan-roms`), Details / Add to Home when a
tile is focused, Settings, Exit. Home-only Reorder / New Collection stay
null on Library. Storefront rescans were Settings-only in M19; see M20.

**Ally open:** idle-hide drops Shortcuts focus, so OpenMenuIntent alone never
sees harness `=` / `+`. Harness opens via WH_KEYBOARD_LL bare **VK_OEM_PLUS**
/ **VK_ADD** → `WM_HOMEDECK_OPEN_MENU` → Dart `openMenu` (same `_menuOpen =
true`), or UIA Invoke on `(+) Menu` / `menu-open-hit` (`Semantics.onTap`).

1. Home: open menu via `=` / `+` / VK_OEM_PLUS **or** UIA Invoke `(+) Menu` /
   `menu-open-hit` → Customize Home; Reorder / New Collection present; no
   Library scan rows.
2. Library: open menu → Rescan Steam / Start Menu / ROMs present; invoke
   `menu-scan-steam` → tiles import (or scan message); close menu.
3. Spot-check title-pill dots on Home, dock idle, focus ring, Enter/Delete,
   F11, and bare **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** /
   **`o`** / **`n`** / **`w`** / **`h`** / **`a`**.

### Ally M20 Library + storefront rescans

Library `+` adds storefront Rescan rows (same import paths as Settings and
harness bare **E** / **G** / **U** / **O** / **N** / **W**): **Rescan Epic
Games** (`menu-scan-epic`), **Rescan GOG** (`menu-scan-gog`), **Rescan
Ubisoft Connect** (`menu-scan-ubisoft`), **Rescan EA App** (`menu-scan-ea`),
**Rescan Battle.net** (`menu-scan-battlenet`), **Rescan Xbox / Microsoft
Store** (`menu-scan-xbox`). Steam / Start Menu / ROM rows from M19 stay.
Home Customize Home stays unchanged — no storefront or Steam/Start/ROM
scan rows. Bare harness keys and Settings buttons are unchanged.

1. Home: open menu (VK_OEM_PLUS or `menu-open-hit`) → Customize Home; no
   Rescan storefront / Steam / Start / ROM rows.
2. Library: open menu → Rescan Steam / Start / ROM **and** Epic / GOG /
   Ubisoft / EA / Battle.net / Xbox present; invoke `menu-scan-epic` (or
   one storefront) → import / message; close menu.
3. Spot-check title-pill / dock / focus, Enter / Delete, F11, and bare
   **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** / **`o`** /
   **`n`** / **`w`** / **`h`** / **`a`**.

### Ally M21 Details menu smoke

Focused game/app **Details** is a real action menu (not a title/path card):
**Add to Home** / **Remove from Home** / **Remove from Library** when
applicable, plus **Close · B**. Kind/path stay as a header subtitle.
Empty slot / no usable focus keeps today’s no-op or close-only sheet —
no invented empty-slot widgets. Do not invent Manage Media, artwork
scrape, RetroAchievements, or per-game settings.

**Ally open:** idle-hide drops Shortcuts focus, so OpenDetailsIntent alone
never sees harness `-`. Harness opens via WH_KEYBOARD_LL bare
**VK_OEM_MINUS** → `WM_HOMEDECK_OPEN_DETAILS` → Dart `openDetails` (same
`_openDetails`), or UIA Invoke on `(-) Details` / `details-open-hit`
(`Semantics.onTap`). Action keys: `details-add-to-home`,
`details-remove-from-home`, `details-remove`, `details-close`.

1. Focus a Library game; open Details via VK_OEM_MINUS **or** UIA Invoke
   `(-) Details` / `details-open-hit` → menu with Add to Home (when not
   pinned); close with B.
2. On a Home pin: Details → Remove from Home works (or Delete still works —
   spot-check).
3. Spot-check title-pill / dock / focus, Enter / Delete, F11, menu-open
   `+` / `menu-open-hit`, Library rescans, and bare **`s`** / **`p`** /
   **`r`** / **`e`** / **`g`** / **`u`** / **`o`** / **`n`** / **`w`** /
   **`h`** / **`a`**.

### Ally M22 Global Search open smoke

`GlobalSearchSheet` + OpenSearchIntent / **Y** already exist but are
Shortcuts-only — same Ally idle-hide gap as pre-fix Menu / Details. Do not
invent new search backends, scrapers, or collections. Sheet keeps
`global-search` / `search-field` / hit keys; hint line includes
**Press X to navigate** (iisu parity) without changing navigation.

**Ally open:** idle-hide drops Shortcuts focus, so OpenSearchIntent alone
never sees harness `y`. Harness opens via WH_KEYBOARD_LL bare **Y**
(`0x59`) → `WM_HOMEDECK_OPEN_SEARCH` → Dart `openSearch` (same
`_openSearch` guards), or UIA Invoke on dock Search / `search-open-hit`
(`Semantics.onTap`). Consume the key in the LL hook to avoid double-open
with Shortcuts.

1. From Home (after idle ok): bare **Y** or SendKeys `y` → Global Search
   opens (`global-search`); type a letter or browse hits; B / Esc closes.
2. From Library: same Y opens search; activate a hit if easy.
3. Spot-check Details OEM_MINUS, Menu OEM_PLUS, title-pill / dock / focus,
   Enter / Delete, F11, and bare **`s`** / **`p`** / **`r`** / **`e`** /
   **`g`** / **`u`** / **`o`** / **`n`** / **`w`** / **`h`** / **`a`**.

### Ally M23 Notifications slide-over smoke

RT-style **Notifications** panel (title Notifications, list or empty
“No notifications”, **Clear notifications**, close with B / Esc). Clock /
battery stay as today. No Discord, no system-tray integration. Do not
invent fake scrape jobs — empty is OK; optional in-app scan/status lines
only when a real Library scan finishes.

**Ally open:** idle-hide drops Shortcuts focus, so OpenNotificationsIntent
alone never sees harness `t`. Harness opens via WH_KEYBOARD_LL bare **T**
(`VK_T` / `0x54`) → `WM_HOMEDECK_OPEN_NOTIFICATIONS` → Dart
`openNotifications` (same `_openNotifications` guards), or UIA Invoke on
StatusCluster bell / `notifications-open-hit` (`Semantics.onTap`, label
**Open notifications**). Consume the key in the LL hook to avoid
double-open with Shortcuts. Do not steal Y / OEM_PLUS / OEM_MINUS /
`s` / `p` / `r` / `e` / `g` / `u` / `o` / `n` / `w` / `h` / `a` / Delete.
Panel keys: `notifications-panel`, `notifications-clear`,
`notifications-close`.

1. From Home: bare **T** or UIA Invoke bell / `notifications-open-hit` →
   `notifications-panel` opens; Clear (if present) / B or Esc closes.
2. From Library: same open still works.
3. Spot-check Y search, Details OEM_MINUS, Menu OEM_PLUS, title-pill /
   dock / focus, Enter / Delete, F11, and bare **`s`** / **`p`** /
   **`r`** / **`e`** / **`g`** / **`u`** / **`o`** / **`n`** / **`w`** /
   **`h`** / **`a`**.

### Ally M24 Friends slide-over smoke

LT-style **Friends** panel (title Friends, empty / stub list “No friends
online”, “0 pinned” OK, close with B / Esc). ProfileCluster avatars + LT
badge stay display chrome; open is via the cluster hit / bare **F**. No
Discord, no OAuth, no real presence APIs — chrome parity only. Dock
Friends tab stays a placeholder this milestone (do not replace its body
unless trivial reuse of the same panel).

**Ally open:** idle-hide drops Shortcuts focus, so OpenFriendsIntent alone
never sees harness `f`. Harness opens via WH_KEYBOARD_LL bare **F**
(`'F'` / `0x46`) → `WM_HOMEDECK_OPEN_FRIENDS` → Dart `openFriends` (same
`_openFriends` guards), or UIA Invoke on ProfileCluster /
`friends-open-hit` (`Semantics.onTap`, label **Open friends**). Consume
the key in the LL hook to avoid double-open with Shortcuts. Do not steal
T / Y / OEM_PLUS / OEM_MINUS / `s` / `p` / `r` / `e` / `g` / `u` / `o` /
`n` / `w` / `h` / `a` / Delete. Panel keys: `friends-panel`,
`friends-close`.

1. From Home: bare **F** or UIA Invoke profile / `friends-open-hit` →
   `friends-panel` opens; B or Esc closes.
2. From Library: same open still works.
3. Spot-check T notifications, Y search, Details OEM_MINUS, Menu
   OEM_PLUS, title-pill / dock / focus, Enter / Delete, F11, and bare
   **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** / **`o`** /
   **`n`** / **`w`** / **`h`** / **`a`**.

### Ally M25 Achievements dock tab smoke

Dock **Achievements** tab is real empty chrome (title Achievements, copy
“No achievements yet”) — not Placeholder. No RetroAchievements login,
scrape, or per-game cards this milestone. Friends dock tab stays
placeholder. Keys: `achievements-tab`, `achievements-empty`.

**Ally jump (shipped):** idle-hide drops Shortcuts focus, so
GotoAchievementsIntent alone never sees harness `c`. Harness jumps via
WH_KEYBOARD_LL bare **C** (`'C'` / `0x43`) → `WM_HOMEDECK_GOTO_ACHIEVEMENTS`
→ Dart `gotoAchievements` (same `_gotoAchievements` guards as dock select).
Consume the key in the LL hook to avoid double-fire with Shortcuts. Do not
steal F / T / Y / OEM_PLUS / OEM_MINUS / `s` / `p` / `r` / `e` / `g` /
`u` / `o` / `n` / `w` / `h` / `a` / Delete. LB/RB and PageDown/PageUp still
reach the tab as today.

1. From Home: LB/RB or PageDown/PageUp to Achievements → `achievements-tab`
   / empty state visible (not Placeholder). Bare **C** jumps there.
2. LB/RB away and back still works; dock idle hide still OK.
3. Spot-check F friends, T notifications, Y search, Details OEM_MINUS, Menu
   OEM_PLUS, title-pill / dock / focus, Enter / Delete, F11, and bare
   **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** / **`o`** /
   **`n`** / **`w`** / **`h`** / **`a`**.

### Ally M26 Games dock tab smoke

Dock **Games** tab is real empty chrome (title Games, copy “No games yet” /
“Pin games from Library”) — not Placeholder. Not a second Library scanner
or grid; Library remains the real library. Friends dock tab stays
placeholder. Keys: `games-tab`, `games-empty`.

**Ally navigation (dock-only this PR):** no bare **V** /
`WM_HOMEDECK_GOTO_GAMES` hook. Reach Games via LB/RB or PageDown/PageUp
(same dock cycle as today). Do not steal C / F / T / Y / OEM_PLUS /
OEM_MINUS / `s` / `p` / `r` / `e` / `g` / `u` / `o` / `n` / `w` / `h` /
`a` / Delete.

1. From Home: LB/RB or PageDown/PageUp to Games → `games-tab` / empty state
   visible (not Placeholder).
2. Cycle away and back; dock idle hide still OK; Achievements **C** still
   works.
3. Spot-check F / T / Y / OEM_± / Enter / Delete / F11 and bare
   **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** / **`o`** /
   **`n`** / **`w`** / **`h`** / **`a`**.

### Ally M27 Friends dock tab smoke

Dock **Friends** tab is real empty chrome (title Friends, copy “No friends
online”) — not Placeholder. Keys: `friends-tab`, `friends-empty`. Shared
empty copy with the LT slide-over (`kFriendsEmptyCopy`). Keep bare **F** /
`friends-open-hit` → `friends-panel` as-is (no Discord / presence APIs).

**Ally navigation (dock-only this PR):** no new LL letter /
`WM_HOMEDECK_GOTO_FRIENDS` hook — **F** already opens the overlay. Reach
the Friends dock tab via LB/RB or PageDown/PageUp (same dock cycle as
today). Do not steal C / F / T / Y / OEM_PLUS / OEM_MINUS / `s` / `p` /
`r` / `e` / `g` / `u` / `o` / `n` / `w` / `h` / `a` / Delete. If a future
goto-tab key is added, call **`ModifierHeld`** (PascalCase) only.

1. From Home: PageDown/PageUp or LB/RB to Friends → `friends-tab` / empty
   (not Placeholder). Bare **F** still opens the slide-over panel.
2. Cycle away/back; dock idle hide still OK; Games + Achievements **C**
   still OK.
3. Spot-check T/Y/OEM_±/Enter/Delete/F11 and bare
   **`s`** / **`p`** / **`r`** / **`e`** / **`g`** / **`u`** / **`o`** /
   **`n`** / **`w`** / **`h`** / **`a`**.

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
- U scans Ubisoft Connect installs into Library (no Home pins)
- O scans EA App / Origin installs into Library (no Home pins)
- N scans Battle.net installs into Library (no Home pins)
- H pins the focused Library record onto Home (same as UI Add to Home)
- C selects the Achievements dock tab (Ally: `WM_HOMEDECK_GOTO_ACHIEVEMENTS`)
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
