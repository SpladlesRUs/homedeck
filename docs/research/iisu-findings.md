# iiSU study (Retroid Pocket 5) and HomeDeck change list

Explored on Tuesday, Nov 24, 2026, afternoon Eastern Time, on the Retroid Pocket 5 (adb serial 3dee0946) from orca. iiSU package `com.iisulauncher`, activity `MainActivity`. Package metadata reports version 0.1.6.1 (versionCode 9, installed Oct 7, 2026). The in-app About screen reports iiSU Launcher / App Version 0.0.7.4 and points at the GitHub project `iiSU-android`. Screen is 1920x1080 landscape (physical 1080x1920, rotation 90, density 360). Exploration was read-only: no settings were saved or toggled, no games or folders were added or removed, nothing was signed into, and the default launcher was not changed. The device was left on iiSU Home, page 1. USB stay-on was restored.

The layout we used is iiSU's **WiiSU mode** (Appearance, Home Layout). That mode "forces horizontal pages with open glass tiles and neighbor peeks," and it locks some layout controls. That is the Wii U-like behavior HomeDeck is chasing.

Current HomeDeck reference (PR 2, commit b37a183) is a 1280x800 8x3 glass grid with empty slots, a always-visible 5-tab dock, a centered title pill, and a Library that stacks one console per vertical section in a single column.

---

## 1. Per-screen notes

### Chrome (shared across top-level screens)

- Top left: overlapping circular avatars with an LT badge. LT opens a **Friends** slide-over (search, Refresh, Pin, "0/5 pinned," Discord presence). This is friends, not a user-switcher.
- Top center: a dark glass title capsule. In Library and inside a console folder it shows the focused item name (for example "Nintendo DS" or "Pokemon HeartGold Version"). On Home in this WiiSU config, "Show title bar on home" is off, so the capsule holds **page dots** (4 pages, the active dot is green) instead of a title.
- Top right: an RT badge, a notifications bell, time, 100% battery with a green icon, and a circular emblem. RT opens a **Notifications** slide-over with two tabs, "iiSU Notifications" and "System Notifications," plus a "Clear notifications" action (not used). Recent items included Multi Scrape and ROM indexing (298 ROMs across 17 consoles). 15 console tiles are visible; two of the 17 likely have no games and are hidden.
- Bottom left: (B) Back and (-) Details. Bottom right: (A) Select and (+) Menu. Hints sit in dark rounded cards.
- Bottom center **tab dock** (5 tabs, LB / RB on the sides): Home (house), Library (gamepad), Trophies (cup), Social (green smiley), Apps (red 6-dot grid). The selected tab glows. The dock **auto-hides** after a short time and while inside a folder or the app drawer. It comes back when you press LB or RB. D-pad down from the bottom row does not move focus onto the dock.

### Home (first dock tab)

WiiSU Home is a paged desktop of pinned shortcuts, not a single 8x3 sheet.

- **Page 1:** a large music widget on the left (about 724x760 px, roughly three rows tall and three small-tile columns wide) with a music-note badge in the corner; to the right, a 3-row grid of about 222 px square tiles with ~28-30 px gaps. Pinned here: Messenger, Pokemon GO, Messages, Minecraft, Facebook, and Plex (yellow chevron). Remaining cells are empty glass slots. A right-pointing chevron and a sliver of the next page peek in from the right edge.
- **Pages 2-4:** a regular 7-column by 3-row grid of empty glass slots, with left/right chevrons and neighbor-page peeks. Page 4 has no right chevron (last page). Tiles are about 224 px square with ~27 px gaps.
- Empty slots stay empty and are focusable. A focused empty slot gets the same cyan-to-purple gradient ring as a filled tile.
- You can also swipe between pages. After a swipe, the focus ring often disappears (see Bugs).
- The + menu on Home is titled **Customize Home**: Widgets, Reorder home, Refresh Home, Global Search, and New Collection, plus a left rail of Settings, Wi-Fi, and Bluetooth. The header previews collection art (a Cave Story set was visible there). Those collections are not one of the four existing home pages; they look like something you add.
- Hero backdrops are currently **disabled on Home** (Media and Background: "Disable heroes on Home" is on), so Home uses a dark dotted glass field instead of game art. Heroes stay enabled inside console folders.

### Library (second dock tab): console folders

This is how iiSU groups the library, and it is the direct answer to "sideways rows vs console folders."

- The Library root is a **5-column by 3-row grid of platform folders**, left-aligned, with empty space on the right. Tiles are rounded glass squares with a colored motif, often a faint watermark of game art inside the tile.
- Opening a folder (A) drills in. B returns to the folder grid. The dock is hidden inside a folder, and LB / RB do not change tabs until you go back.
- The 15 folders on this device, in grid order:
  1. Nintendo 3DS  2. Nintendo Game Boy  3. Nintendo GameCube  4. Sega Genesis  5. Valve Steam
  6. Nintendo 64  7. Nintendo Game Boy Advance  8. Nintendo Switch  9. Sony PlayStation  10. Nintendo DS
  11. Nintendo Entertainment System  12. Nintendo Game Boy Color  13. Nintendo Wii  14. Sony PlayStation 2  15. Android
- **Console game folder** (Nintendo DS was fully used): layout changes to a **3-column grid of cartridge / box-art tiles on the left**, with a **full-bleed hero painting of the focused game on the right**. The title pill follows the focused game. Moving focus crossfades the hero after a short settle (settings: 350 ms asset settle delay, then hero scale-in plus shared crossfade). Focus does not wrap off the edges and did not scroll to a second page in that 9-game folder.
- **Android** used the same folder pattern but with a dark dotted backdrop (no game hero).
- Pressing B on the Library root, with "App drawer" bound to B, opened the **Recents / app drawer** (7-column app grid). The title pill incorrectly stayed on "Valve Steam." This is easy to misread as a Steam folder.

### Trophies (third dock tab)

A mostly empty dark field with a wide achievement card at the top left: Need for Speed Underground, 6/113, a row of achievement icons, and a progress bar. More games would presumably stack below. No title pill.

### Social (fourth dock tab)

The smiley is in the dock but **LB / RB skipped this tab** (Library went to Trophies, then to Apps). A tap on the icon was not successfully delivered (coordinate / dock-hide timing). This tab was not opened. Treat the skip as a bug to avoid, and as a gap in this study.

### Apps (fifth dock tab)

A left column of three category tiles: a 3x3 app-grid icon, the Android / Play Games mark, and a space-invader (arcade-style) icon. The Recents app drawer (opened via B) is a related all-apps / recents grid.

### Details (-) menu on a game

A dimmed, dotted overlay with a large centered card: pencil + game name, then **Manage Media** (banner), **Settings**, **RetroAchievements**, and **Add to home**. "Add to home" confirms Library items are not automatically pinned; Home is a separate desktop of shortcuts. The menu was closed with B. Nothing was added.

Details on an empty Home slot did not show a useful overlay in the capture (the menu may be a no-op there).

### Plus menu and Settings (view only)

Settings is a full pane with a left nav: Find a setting, General, Appearance, Library, Audio, Input, Performance, About.

Useful Appearance values currently in effect (not changed):

- Theme Style: Dark. Font: Cal Sans. Custom selection gradient: off (the default ring is still a cyan-to-purple gradient). Glass blur is on.
- Home mode: **WiiSU** (not Standard). Standard is described as "current continuous dashboard behavior."
- Show title bar on home: off (locked in WiiSU). Show title bar on games: on. Use title image: off.
- Show System Status, Connected Friends, RA overview, and Button Hints: on. Gameplay slides: off.
- Heroes: disabled on Home, enabled on the games grid. Background opacity 25%. Dark-mode platform icons: on. Video theme backgrounds are supported but off.
- Motion: animate heroes, page transition Pop, selection gradient animations, grid domino animations, asset settle delay **350 ms**.
- Audio: UI effects on at 100%, haptics Weak, home music **"iiSU Home Menu Theme"** at 100%, plus Add Custom Music. Music is an Ogg Vorbis stream. It paused when Plex launched and resumed when returning to iiSU. UI clicks come from a SoundPool and fire on focus moves.
- Input: RetroAchievements popup is X, screen swap is Y, app drawer is B, right stick is Scroll. Swap A/B and X/Y is off. Tap-to-focus-first is off.
- Library settings (not run): Rescan, Add game library folder, scan depth 5, one linked folder named `roms`.
- Default launch page: Home. Low Power Mode: inactive.

Customize Platforms (Library + menu): Add Console, Reorder consoles, Global Search, Scrape all consoles, Manage Library, Dynamic Borders. Manage Library opens the Settings Library page. No scrape or add was started.

### Global Search

Search field: "Search ROMs, consoles, apps, collections, and folders." Hints: Press A to open, Press X to navigate, Press B to close. Unfiltered results were a vertical list with box art, title, console, and a ROM badge (Black 2, Majora's Mask 3D, Mario Kart 8 Deluxe, Mario vs. Donkey Kong). Closed without typing.

### Launch and return

A (after a focus-loss swipe) launched Plex, which went full screen to its sign-in page. Nothing was signed in. The Android Home key returned to iiSU. Menu music paused on launch and resumed on return. The launch itself is a hard cut to the app; iiSU does not keep its chrome on screen.

### Sound and motion (inferred)

- Looping home menu music while iiSU is in the foreground.
- Short UI sonification on focus moves and some confirms.
- Focus highlight is an animated gradient ring; the focused tile feels slightly lifted.
- Hero and title wait 350 ms after you stop moving, then crossfade and scale in. That keeps fast scrolling from thrashing artwork.
- Page transition is set to Pop.
- Grid items can play a "domino" entrance when entering or returning to a screen.

---

## 2. Prioritized HomeDeck changes

Constraints: Windows only. No Nintendo or other trademarked art, wordmarks, or official logos (iiSU uses those; HomeDeck must keep the original glass motifs). Home stays a pinned desktop. Library stays everything, grouped by console or by app. Tre is choosing sideways rows vs console folders; iiSU uses folders.

1. **Library as platform folders, not a single-column stack (high).** Replace the current "By console" vertical list (one game per row, one column) with a folder grid like iiSU: each console or store is a tile, A opens that group's games, B returns. "By app" should work the same for Steam, Epic, GOG, Xbox, and desktop apps. This is how iiSU actually works and is the cleaner of Tre's two options. Sideways rows are not what iiSU does.
2. **Inside a console folder, use 3-column box art plus a full-bleed hero (high).** When a folder is open, put game tiles on the left and the focused game's art on the right (or as a full-screen backdrop). Crossfade the hero and title only after a short settle (copy the 350 ms delay, then scale-in plus fade). Do not use official box art we do not have rights to; use user-supplied art, scraped art the user already has, or a colored glass tile.
3. **Paged Home with empty slots and neighbor peeks (high).** Keep pinned shortcuts and empty cells, but add horizontal pages, page dots in the top capsule, and a sliver of the next and previous pages with chevrons. Leave unused pages empty instead of collapsing them. This is the WiiSU desktop, and it is closer to "Home like a desktop" than a single 8x3 panel.
4. **A large featured tile on Home page 1 (medium-high).** Give page 1 a big left-hand widget (music, now playing, or last played) that spans the height of the pin grid, with ordinary pins to the right. The flat 8x3 grid can remain as "Standard" mode, matching iiSU's Standard vs WiiSU switch.
5. **Animated focus, not a static outline (medium-high).** Use a cyan-to-purple gradient ring, a slight scale-up, and a short highlight animation. Keep empty slots focusable with the same ring.
6. **Auto-hiding dock, but do not drop tabs (medium).** Keep the same 5-tab Home / Library / Trophies / Social / Apps idea and LB / RB. Hide the dock inside folders and after a short idle, and show it again on LB / RB. Always allow D-pad or a hold to focus the dock as a fallback. Never skip a tab, and still let LB / RB work inside a folder (or clearly consume B only as Back there).
7. **Context-sensitive title pill (medium).** Library and folders: centered name of the focused item (already the HomeDeck direction). Paged Home: page dots can occupy that slot, or make the name a setting. Keep the pill truly centered.
8. **Context-sensitive + menu (medium).** Home: widgets, reorder, search, new page or collection. Library: add platform, manage library, rescan / scrape, visuals. Shared left rail for Settings. Do not invent trademarked theme packs.
9. **Global search (medium).** One search over games, platforms, apps, and folders, with keyboard plus A / B / X hints, list results, and B to close.
10. **Details menu on a game (medium).** Manage media / artwork, per-game settings, achievements, and Add to Home. Library games should not appear on Home until pinned.
11. **Menu music and UI clicks (medium).** The 10-song playlist should start at a random track, loop, pause when a game or app launches, and resume when the launcher comes back. Keep UI clicks as short code-generated sounds, not long Suno clips. Expose a music picker and volume in Settings.
12. **Chrome parity (lower, already close).** Keep LT-style profile / friends cluster, RT-style clock, battery, and notifications, and the A / B / - / + corner hints. Friends and notifications as side panels are worth adding later.
13. **Optional later:** a Trophies tab with per-game achievement cards; an Apps / Recents drawer; home music as a real widget; a 350 ms-quality motion settings page (page pop, hero fade, grid entrance).

What not to copy: official console logos and box art; B bound to both Back and App drawer at the root; hiding the dock with no other way to reach it; stale titles; focus loss after a page change.

---

## 3. iiSU bugs and rough edges to avoid

- **Focus loss after a Home page swipe.** After swiping to pages 2-4, the focus ring often vanished. Pressing A then launched Plex (a page-1 pin) instead of the visible empty slot. HomeDeck must keep a stable focus after paging, and must not launch a hidden or previous item when focus is unclear.
- **LB / RB do nothing inside a folder or the app drawer.** You have to B out first. Shoulder buttons should still switch tabs, or Back should be the only way out and that should be obvious.
- **The Social dock tab is skipped by LB / RB.** The icon is there; the shoulders jump from Trophies to Apps. Every visible tab must be reachable.
- **Stale title pill.** The Recents / app drawer kept the previous "Valve Steam" title. The pill should always describe the view you are in.
- **B is overloaded.** In settings, B is App drawer at the Library root and Back everywhere else. One button, two meanings, caused a surprising jump into Recents. Use a dedicated binding for an app drawer.
- **Down from the last row cannot reach the dock.** If the dock is hidden or unfocusable, a user who does not think of LB / RB can get stuck on the idea that there are no other tabs.
- **Title and package versions disagree** (0.0.7.4 on About vs 0.1.6.1 on the APK). Not a UX bug, but HomeDeck should show one truthful version string.
- No crash, no freeze, and no lasting settings change occurred during this session. Lock screen "Press A to unlock" and the notification shade sitting on top of the lock screen are Android / device behavior, not iiSU itself.

---

## 4. Key screenshot paths

The most useful frames, already on the box:

1. `/workspace/iisu-study/key/01-home-page1-widget-pins-empty.png` — Home page 1: large music widget, pins, empty slots, page dots, dock.
2. `/workspace/iisu-study/key/02-home-page2-empty-slots-peeks.png` — Home page 2: empty 7x3 grid, neighbor peeks, focused empty slot.
3. `/workspace/iisu-study/key/03-library-console-folders.png` — Library root: 5x3 platform folders and dock.
4. `/workspace/iisu-study/key/04-console-folder-hero-backdrop.png` — Nintendo DS folder: 3-column box art and full-bleed hero.
5. `/workspace/iisu-study/key/05-game-details-menu.png` — Details menu, including Add to home.
6. `/workspace/iisu-study/key/06-customize-home-menu.png` — Customize Home plus menu.
7. `/workspace/iisu-study/key/07-customize-platforms-menu.png` — Customize Platforms plus menu.
8. `/workspace/iisu-study/key/08-global-search.png` — Global search results.

Also useful: `09-trophies-tab.png`, `10-friends-panel.png`, `11-notifications-panel.png`, `12-settings-wiisu-mode.png`, `13-app-drawer-recents.png`. Raw captures and settings pages live under `/workspace/iisu-study/` (including `73-motion.png`, `75-settings-audio.png`, `69-manage-library.png`). A 12-second focus-move recording is on orca at `/Users/grokbot/iisu-study/focus-move.mp4`.
