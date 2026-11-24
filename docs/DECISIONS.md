# HomeDeck decisions (milestone 1)

## Open product questions

These stay unresolved on purpose. The data model is not narrowed around either
answer.

1. **Library scope.** Is HomeDeck limited to games and emulators, or does it
   include general applications? Records already support an optional `category`
   and a free-form display name. Milestone 1 does not filter the library.
2. **Manual add vs discovery.** Milestone 1 is **manual add only** (file picker
   for `.exe` / `.lnk`). `PlatformAdapter.discover()` exists and returns an
   empty list so a scanner can replace it later without touching widgets.

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
| Windows `.lnk` launch via `cmd /c start` | Implemented as best-effort; **not verified on real Windows** |
| Windows PE / `.lnk` icon extraction | Not implemented; generated tiles used |
| Installed-app scanner | Not implemented |
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

Add an app with the on-screen **Add** tile or the `A` key, pick a `.exe` or
`.lnk`, then press Enter (or click) to launch. Layout is stored in the
application support directory provided by `path_provider` (typically under
`%AppData%`) as `library.json`. Cached icons live next to it in `icons\`.

Keyboard:

- Arrow keys move focus
- Enter launches
- Delete / Backspace removes from the library
- Esc dismisses overlays
- M enters rearrange mode (arrows swap tiles; drag also works)
- F11 toggles fullscreen
- Ctrl+, opens the settings stub

The layout is designed for 1280×720, 1920×1080, and 3840×2160.

## Linux desktop target (shared UI only)

Linux is enabled so developers can run and screenshot the shared interface.
It still uses `WindowsAdapter` contracts (manual `.exe`/`.lnk` add, generated
icons, validation). It does not launch Linux applications.

```bash
flutter run -d linux --dart-define=HOMEDECK_SEED_DEMO=true
```

`HOMEDECK_SEED_DEMO` seeds colorful demo tiles for screenshots, including one
unavailable target used to show launch-error feedback.
