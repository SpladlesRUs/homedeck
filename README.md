# homedeck

<img src="assets/branding/homedeck-icon.png" alt="HomeDeck" width="160" height="160" />

<a href="https://www.buymeacoffee.com/spladlesrus" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" style="height: 60px !important;width: 217px !important;" ></a>

## License

homedeck is source-available under the [Horton Press Personal Use License 1.0.0](LICENSE), adapted from the PolyForm Strict License 1.0.0. It is not an open source license.

- Free for personal, non-commercial use.
- You may not fork, redistribute, modify for distribution, sublicense, or use homedeck commercially without written permission from Horton Press.
- Provided with no warranty and with a limitation of liability.

Copyright (c) 2026 Horton Press. For permission requests, contact support@hortonpress.com.

## What is HomeDeck?

HomeDeck is a console-style app launcher. Milestone 1 targets Windows: a
colorful tile grid you can read from across the room, keyboard and mouse
navigation, manual add of `.exe` / `.lnk` files, launch with clear errors, and
a layout that is remembered after restart.

Branding is original. There are no Nintendo logos, names, or artwork.

Architecture, platform adapters, and how to add macOS / Android / Linux (Steam
Deck) later: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Open questions, icon limits, and Windows run instructions:
[docs/DECISIONS.md](docs/DECISIONS.md).

## Run on Windows

```bat
flutter pub get
flutter run -d windows
```

`F11` toggles fullscreen. Settings (Ctrl+,) also exposes borderless chrome.

## Linux desktop target (shared UI only)

Linux is enabled so the shared interface can be developed and screenshotted.
It does **not** implement Linux or Steam Deck launch behavior.

```bash
flutter pub get
flutter run -d linux --dart-define=HOMEDECK_SEED_DEMO=true
```

## Proof screenshots (Linux shared UI)

These images are from a Linux run of the shared UI, not from a Windows launch:

- [Home grid with tiles](docs/proof/linux-shared-ui/01-home-grid-tiles.png)
- [Focus state](docs/proof/linux-shared-ui/02-focus-state.png)
- [Launch-error feedback](docs/proof/linux-shared-ui/03-launch-error.png)
- [Fullscreen](docs/proof/linux-shared-ui/04-fullscreen.png)

## Open questions

- Should the library be limited to games and emulators, or include general apps?
- Manual add only (current) versus automatic installed-app discovery?
