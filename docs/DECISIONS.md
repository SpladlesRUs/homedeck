# HomeDeck decisions (milestone 1)

## Open product questions

These stay unresolved on purpose. The data model is not narrowed around either
answer.

1. **Library scope.** Is HomeDeck limited to games and emulators, or does it
   include general applications? Records already support an optional `category`
   and a free-form display name. Milestone 1 does not filter the library.
2. **Manual add vs discovery.** Milestone 1 is **manual add only**. The Add
   sheet can register a native `.exe` / `.lnk` / store URI, or an emulated
   game (emulator + ROM + `{rom}` args). `PlatformAdapter.discover()` exists
   and returns an empty list so a Steam / ROM-folder scanner can replace it
   later without touching widgets.

## Official app icon

Tre supplied `assets/branding/homedeck-icon.png` (1254×1254). That file is stored
unaltered. Windows `windows/runner/resources/app_icon.ico` is generated from it
with 16, 24, 32, 48, 64, 128, and 256 px layers for the window and taskbar
(via `IDI_APP_ICON` in the runner). The in-app header, settings/about, and
README use the same PNG.

## Windows icon extraction

HomeDeck does **not** extract icons from PE resources or `.lnk` files in
milestone 1. Dart has no built-in `ExtractIconEx` binding, and pulling a Win32
FFI plugin was out of scope.

When an icon cannot be read, HomeDeck generates a colored tile with the app
initial and caches it as a PNG under the application support directory
(`icons/<id>.png`, stored as a relative `iconRef`).

A later Windows adapter can resolve real icons (Win32, PowerShell, or a
shortcut parser) and write the same cache format.

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
| Emulator + ROM launch with `{rom}` args | Implemented; **not verified on real Windows** |
| Windows PE / `.lnk` icon extraction | Not implemented; generated tiles used |
| Installed-app / Steam / ROM-folder scanner | Not implemented; `discover()` is the hook |
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
(window title **Open**, OK label **Add to HomeDeck**) via the runner
`homedeck/win32` channel and persist + pin to Home immediately — Ally Phase2
SendKeys `a` expects a FindWindow-able `Open` / `#32770` dialog and checks
`library.json` after it closes (it never Confirms an in-app sheet). Tip
`bdd3ba1` still failed because `file_selector`'s `IFileDialog` never produced
a harness-visible Open window (`Open dialog not found` → `apps=[]`). Optional
`HOMEDECK_ADD_PATH` bypasses the modal with a fixed exe/lnk for automation.
Emulated / URI add uses Menu → Add game (sheet). Then press Enter (or click)
to launch.
Layout is stored in the application support directory provided by
`path_provider` (typically under `%AppData%`) as `library.json`. Cached icons
live next to it in `icons\`. `PreferencesRepository` seeds `library.json` on
first load and saves with a flushed direct write (temp copy + final overwrite
+ apps round-trip check) under `%AppData%\Horton Press\HomeDeck\`. Empty
`apps[]` writes never clobber a non-empty on-disk library. `LibraryController`
serializes commits and persists the live `_state` at write time. Windows
launches use the runner `homedeck/win32` MethodChannel (`ShellExecuteW`), then
Dart FFI / CreateProcess / `cmd /c start`. Ally Phase2 drives keys with
`WScript.Shell.SendKeys` (not top-level `WM_KEYDOWN`), so the runner installs
a `WH_KEYBOARD_LL` hook for F11 chrome and Enter→focused path while HomeDeck
is foreground; Dart mirrors the focused launch target and handles a native
`launchFocused` fallback when the mirror is empty.

Keyboard:

- Arrow keys move focus
- Enter launches (Add sheet also handles Enter / A via `LaunchFocusedIntent`)
- Delete / Backspace unpins from Home; in Library it asks to remove the game
- Esc dismisses overlays
- M enters rearrange mode (arrows swap tiles; drag also works)
- F11 toggles fullscreen
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
