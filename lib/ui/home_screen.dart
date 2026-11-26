import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:homedeck/core/device_status.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/library_groups.dart';
import 'package:homedeck/core/menu_music.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/core/models/game_source.dart';
import 'package:homedeck/core/models/home_deck_state.dart';
import 'package:homedeck/core/models/launch_outcome.dart';
import 'package:homedeck/core/ui_clicks.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/core/models/app_platform.dart';
import 'package:homedeck/platform/windows_adapter.dart';
import 'package:homedeck/platform/windows_native_bridge.dart';
import 'package:homedeck/ui/add_tile_sheet.dart';
import 'package:homedeck/ui/branding.dart';
import 'package:homedeck/ui/home_grid.dart';
import 'package:homedeck/ui/home_pager.dart';
import 'package:homedeck/ui/intents.dart';
import 'package:homedeck/ui/launch_error_view.dart';
import 'package:homedeck/ui/library_view.dart';
import 'package:homedeck/ui/menu_chrome.dart';
import 'package:homedeck/ui/now_playing_tile.dart';
import 'package:homedeck/ui/search_sheet.dart';
import 'package:homedeck/ui/settings_stub.dart';
import 'package:homedeck/ui/tile_menu.dart';
import 'package:material_ui/material_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.windowMode,
    this.gamepad,
    this.deviceStatus,
    this.music,
  });

  /// Widget tests disable the clock so `pumpAndSettle` can finish.
  static bool tickClock = true;

  /// Tests freeze the clock for screenshots.
  static DateTime Function() clock = DateTime.now;

  final LibraryController controller;
  final WindowModeController windowMode;
  final GamepadSource? gamepad;
  final DeviceStatus? deviceStatus;
  final MenuMusicController? music;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _focusedId;
  String? _hoveredId;
  bool _moveMode = false;
  bool _settingsOpen = false;
  bool _steamScanBusy = false;
  String? _steamScanMessage;
  bool _startMenuScanBusy = false;
  String? _startMenuScanMessage;
  bool _romScanBusy = false;
  String? _romScanMessage;
  bool _epicScanBusy = false;
  String? _epicScanMessage;
  bool _gogScanBusy = false;
  String? _gogScanMessage;
  bool _ubisoftScanBusy = false;
  String? _ubisoftScanMessage;
  bool _eaScanBusy = false;
  String? _eaScanMessage;
  bool _detailsOpen = false;
  bool _addOpen = false;
  bool _menuOpen = false;
  bool _chipsFocused = false;
  bool _searchOpen = false;
  bool _dockForced = false;
  LibraryGroupMode _libraryMode = LibraryGroupMode.console;
  String? _folderTitle;
  LaunchFailure? _failure;
  String? _failureApp;
  String? _pendingRemoveId;
  int _page = 0;
  int _extraHomePages = 0;
  HomeTab _tab = HomeTab.home;
  Timer? _clock;
  DateTime _now = HomeScreen.clock();
  DateTime _lastConfirm = DateTime.fromMillisecondsSinceEpoch(0);
  final _focusNodes = <String, FocusNode>{};
  final _clicks = UiClickPlayer();

  LibraryController get _library => widget.controller;
  WindowModeController get _window => widget.windowMode;
  GamepadSource get _gamepad => widget.gamepad ?? IdleGamepadSource();
  DeviceStatus get _status => widget.deviceStatus ?? MemoryDeviceStatus();

  @override
  void initState() {
    super.initState();
    _library.addListener(_onLibrary);
    _window.addListener(_onWindowMode);
    widget.music?.addListener(_onLibrary);
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    if (Platform.isWindows) {
      WindowsNativeBridge.ensureInitialized();
      WindowsNativeBridge.onLaunchFocused = _launchFocusedFromNative;
      WindowsNativeBridge.onAddPickedPath = _addPickedPathFromNative;
      WindowsNativeBridge.onScanSteam = _scanSteamFromNative;
      WindowsNativeBridge.onScanStartMenu = _scanStartMenuFromNative;
      WindowsNativeBridge.onScanRoms = _scanRomsFromNative;
      WindowsNativeBridge.onScanEpic = _scanEpicFromNative;
      WindowsNativeBridge.onScanGog = _scanGogFromNative;
      WindowsNativeBridge.onScanUbisoft = _scanUbisoftFromNative;
      WindowsNativeBridge.onScanEa = _scanEaFromNative;
      WindowsNativeBridge.onPinFocusedToHome = _pinFocusedToHomeFromNative;
      WindowsNativeBridge.onRemoveFocused = _removeFocusedFromNative;
      WindowsNativeBridge.onConfirmFocused = _confirmFocusedFromNative;
      WindowsNativeBridge.onGameExited = _gameExitedFromNative;
      // Ally Enter ShellExecutes natively — mirror Settings prefs so the
      // runner can enter F11 chrome and restore on process exit.
      unawaited(
        WindowsNativeBridge.setFullscreenOnLaunch(
          _library.state.window.fullscreenOnLaunch,
        ),
      );
      unawaited(
        WindowsNativeBridge.setRestoreOnExit(
          _library.state.window.restoreOnExit,
        ),
      );
    }
    _gamepad.start(_onGamepad);
    _status.start(_onLibrary);
    if (HomeScreen.tickClock) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _now = HomeScreen.clock());
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusedId != null) {
        return;
      }
      if (_tab == HomeTab.home) {
        _focusId(nowPlayingId, click: false);
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    if (Platform.isWindows) {
      if (identical(
        WindowsNativeBridge.onLaunchFocused,
        _launchFocusedFromNative,
      )) {
        WindowsNativeBridge.onLaunchFocused = null;
      }
      if (identical(
        WindowsNativeBridge.onAddPickedPath,
        _addPickedPathFromNative,
      )) {
        WindowsNativeBridge.onAddPickedPath = null;
      }
      if (identical(WindowsNativeBridge.onScanSteam, _scanSteamFromNative)) {
        WindowsNativeBridge.onScanSteam = null;
      }
      if (identical(
        WindowsNativeBridge.onScanStartMenu,
        _scanStartMenuFromNative,
      )) {
        WindowsNativeBridge.onScanStartMenu = null;
      }
      if (identical(WindowsNativeBridge.onScanRoms, _scanRomsFromNative)) {
        WindowsNativeBridge.onScanRoms = null;
      }
      if (identical(WindowsNativeBridge.onScanEpic, _scanEpicFromNative)) {
        WindowsNativeBridge.onScanEpic = null;
      }
      if (identical(WindowsNativeBridge.onScanGog, _scanGogFromNative)) {
        WindowsNativeBridge.onScanGog = null;
      }
      if (identical(
        WindowsNativeBridge.onScanUbisoft,
        _scanUbisoftFromNative,
      )) {
        WindowsNativeBridge.onScanUbisoft = null;
      }
      if (identical(WindowsNativeBridge.onScanEa, _scanEaFromNative)) {
        WindowsNativeBridge.onScanEa = null;
      }
      if (identical(
        WindowsNativeBridge.onPinFocusedToHome,
        _pinFocusedToHomeFromNative,
      )) {
        WindowsNativeBridge.onPinFocusedToHome = null;
      }
      if (identical(
        WindowsNativeBridge.onRemoveFocused,
        _removeFocusedFromNative,
      )) {
        WindowsNativeBridge.onRemoveFocused = null;
      }
      if (identical(
        WindowsNativeBridge.onConfirmFocused,
        _confirmFocusedFromNative,
      )) {
        WindowsNativeBridge.onConfirmFocused = null;
      }
      if (identical(WindowsNativeBridge.onGameExited, _gameExitedFromNative)) {
        WindowsNativeBridge.onGameExited = null;
      }
    }
    _clock?.cancel();
    _gamepad.stop();
    _status.stop();
    _library.removeListener(_onLibrary);
    _window.removeListener(_onWindowMode);
    widget.music?.removeListener(_onLibrary);
    unawaited(_clicks.dispose());
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Runner WH_KEYBOARD_LL / WM_KEYDOWN Enter when mirrored path was empty.
  Future<void> _launchFocusedFromNative() async {
    if (!mounted) {
      return;
    }
    // Library remove confirm / failure: Enter confirms via `_handleConfirm`
    // even though `_overlayOpen` is true (must not no-op and leave armed).
    if (_pendingRemoveId != null || _failure != null) {
      _handleConfirm();
      return;
    }
    if (_overlayOpen) {
      return;
    }
    _handleConfirm();
  }

  /// Runner WH_KEYBOARD_LL Enter while remove-armed / WM_HOMEDECK_CONFIRM.
  Future<void> _confirmFocusedFromNative() async {
    if (!mounted) {
      return;
    }
    _handleConfirm();
  }

  /// Runner WH_KEYBOARD_LL `A` opened classic Open (or HOMEDECK_ADD_PATH) and
  /// returned a path — persist + pin so Ally Enter can ShellExecute.
  Future<void> _addPickedPathFromNative(String path) async {
    if (!mounted || _overlayOpen) {
      return;
    }
    final picked = WindowsAdapter.pickedLaunchFromPath(path);
    if (picked == null) {
      return;
    }
    final added = await _library.addRecord(
      displayName: picked.displayName,
      target: picked.target,
      kind: picked.kind,
      pinToHome: true,
    );
    if (!mounted) {
      return;
    }
    await _focusAddedApp(added);
  }

  /// Runner WH_KEYBOARD_LL bare `S` / WM_HOMEDECK_SCAN_STEAM — same import as
  /// Settings → Scan Steam, without opening the Settings overlay (Ally UIA).
  Future<void> _scanSteamFromNative() async {
    if (!mounted) {
      return;
    }
    // Allow while Settings is open so a human/hotkey scan still updates the
    // message; skip only while Add/OFN-style overlays own the session.
    if (_addOpen || _menuOpen || _searchOpen || _failure != null) {
      return;
    }
    await _scanSteamLibrary();
  }

  /// Runner WH_KEYBOARD_LL bare `P` / WM_HOMEDECK_SCAN_START_MENU — same
  /// import as Settings → Scan Start Menu (Ally without Settings UIA).
  Future<void> _scanStartMenuFromNative() async {
    if (!mounted) {
      return;
    }
    if (_addOpen || _menuOpen || _searchOpen || _failure != null) {
      return;
    }
    await _scanStartMenu();
  }

  /// Runner WH_KEYBOARD_LL bare `R` / WM_HOMEDECK_SCAN_ROMS — same import as
  /// Settings → Scan ROM folder (Ally without Settings UIA).
  Future<void> _scanRomsFromNative() async {
    if (!mounted) {
      return;
    }
    if (_addOpen || _menuOpen || _searchOpen || _failure != null) {
      return;
    }
    await _scanRomFolder();
  }

  /// Runner WH_KEYBOARD_LL bare `E` / WM_HOMEDECK_SCAN_EPIC — same import as
  /// Settings → Scan Epic Games (Ally without Settings UIA).
  Future<void> _scanEpicFromNative() async {
    if (!mounted) {
      return;
    }
    if (_addOpen || _menuOpen || _searchOpen || _failure != null) {
      return;
    }
    await _scanEpicLibrary();
  }

  /// Runner WH_KEYBOARD_LL bare `G` / WM_HOMEDECK_SCAN_GOG — same import as
  /// Settings → Scan GOG (Ally without Settings UIA).
  Future<void> _scanGogFromNative() async {
    if (!mounted) {
      return;
    }
    if (_addOpen || _menuOpen || _searchOpen || _failure != null) {
      return;
    }
    await _scanGogLibrary();
  }

  /// Runner WH_KEYBOARD_LL bare `U` / WM_HOMEDECK_SCAN_UBISOFT — same import
  /// as Settings → Scan Ubisoft Connect (Ally without Settings UIA).
  Future<void> _scanUbisoftFromNative() async {
    if (!mounted) {
      return;
    }
    if (_addOpen || _menuOpen || _searchOpen || _failure != null) {
      return;
    }
    await _scanUbisoftLibrary();
  }

  /// Runner WH_KEYBOARD_LL bare `O` / WM_HOMEDECK_SCAN_EA — same import as
  /// Settings → Scan EA App (Ally without Settings UIA).
  Future<void> _scanEaFromNative() async {
    if (!mounted) {
      return;
    }
    if (_addOpen || _menuOpen || _searchOpen || _failure != null) {
      return;
    }
    await _scanEaLibrary();
  }

  /// Runner WH_KEYBOARD_LL bare `H` / WM_HOMEDECK_PIN_HOME — same as UI
  /// Add to Home on the focused Library record (Ally without menu UIA).
  Future<void> _pinFocusedToHomeFromNative() async {
    if (!mounted) {
      return;
    }
    if (_addOpen || _menuOpen || _searchOpen || _failure != null) {
      return;
    }
    await _pinFocusedToHome();
  }

  /// Runner WH_KEYBOARD_LL bare Delete/Backspace / WM_HOMEDECK_REMOVE — same
  /// as RemoveFocusedIntent / `_requestRemove` (Ally without menu UIA).
  Future<void> _removeFocusedFromNative() async {
    if (!mounted) {
      return;
    }
    if (_addOpen ||
        _menuOpen ||
        _searchOpen ||
        _failure != null ||
        _pendingRemoveId != null) {
      // Native already armed Delete; disarm so Enter can launch again.
      await WindowsNativeBridge.setRemoveArmed(false);
      _syncNativeFocusedLaunch();
      return;
    }
    _requestRemove();
    if (!mounted) {
      return;
    }
    if (_pendingRemoveId == null) {
      // Home unpin — no confirm overlay; restore Enter→launch.
      await WindowsNativeBridge.setRemoveArmed(false);
      _syncNativeFocusedLaunch();
    }
    // Library pending: stay armed; mirror stays cleared until confirm/cancel.
  }

  Future<void> _pinFocusedToHome() async {
    final focused = _focusedRecord;
    if (focused == null) {
      return;
    }
    await _library.pinToHome(focused.id);
    if (!mounted) {
      return;
    }
    // Ally M5: land on Home with the pinned tile focused and refresh the
    // Enter/WH_KEYBOARD_LL launch mirror. Staying on Library left a stale
    // focus; dock→Home then focused Now Playing and wiped setFocusedLaunch.
    await _focusAddedApp(focused);
  }

  Future<void> _focusAddedApp(AppRecord added) async {
    setState(() {
      _tab = HomeTab.home;
      _folderTitle = null;
      _dockForced = true;
      _focusedId = added.id;
    });
    await _syncNativeFocusedLaunchAwait();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusId(added.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _nodeFor(added.id).requestFocus();
        unawaited(_syncNativeFocusedLaunchAwait());
      });
    });
  }

  Future<void> _scanSteamLibrary() async {
    if (_steamScanBusy) {
      return;
    }
    setState(() {
      _steamScanBusy = true;
      _steamScanMessage = null;
    });
    try {
      final added = await _library.importDiscovered(pinToHome: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _steamScanBusy = false;
        if (added == 0) {
          _steamScanMessage =
              'No new Steam games found. Install Steam or add games, then scan again.';
        } else if (added == 1) {
          _steamScanMessage =
              'Added 1 Steam game to Library. Open Library → By app → Steam.';
        } else {
          _steamScanMessage =
              'Added $added Steam games to Library. Open Library → By app → Steam.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _steamScanBusy = false;
        _steamScanMessage = 'Steam scan failed: $error';
      });
    }
  }

  Future<void> _scanStartMenu() async {
    if (_startMenuScanBusy) {
      return;
    }
    setState(() {
      _startMenuScanBusy = true;
      _startMenuScanMessage = null;
    });
    try {
      final added = await _library.importStartMenu(pinToHome: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _startMenuScanBusy = false;
        if (added == 0) {
          _startMenuScanMessage =
              'No new Start Menu apps found. Check Programs shortcuts, then scan again.';
        } else if (added == 1) {
          _startMenuScanMessage =
              'Added 1 Start Menu app to Library. Open Library → By app.';
        } else {
          _startMenuScanMessage =
              'Added $added Start Menu apps to Library. Open Library → By app.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startMenuScanBusy = false;
        _startMenuScanMessage = 'Start Menu scan failed: $error';
      });
    }
  }

  Future<void> _pickRomRoot() async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Use ROM folder',
    );
    if (path == null || path.trim().isEmpty || !mounted) {
      return;
    }
    await _library.setRomRoot(path);
    if (!mounted) {
      return;
    }
    setState(() {
      _romScanMessage = 'ROM folder set. Scan to import emulated tiles.';
    });
  }

  Future<void> _scanRomFolder() async {
    if (_romScanBusy) {
      return;
    }
    setState(() {
      _romScanBusy = true;
      _romScanMessage = null;
    });
    try {
      final added = await _library.importRoms(pinToHome: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _romScanBusy = false;
        if (added == 0) {
          _romScanMessage =
              'No new ROMs found. Set a ROM folder (or HOMEDECK_ROM_ROOT), then scan again.';
        } else if (added == 1) {
          _romScanMessage =
              'Added 1 ROM to Library. Open Library → By console / Emulated. If launch fails, set an emulator via HOMEDECK_EMULATOR or Manual Add.';
        } else {
          _romScanMessage =
              'Added $added ROMs to Library. Open Library → By console / Emulated. If launch fails, set an emulator via HOMEDECK_EMULATOR or Manual Add.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _romScanBusy = false;
        _romScanMessage = 'ROM scan failed: $error';
      });
    }
  }

  Future<void> _scanEpicLibrary() async {
    if (_epicScanBusy) {
      return;
    }
    setState(() {
      _epicScanBusy = true;
      _epicScanMessage = null;
    });
    try {
      final added = await _library.importEpic(pinToHome: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _epicScanBusy = false;
        if (added == 0) {
          _epicScanMessage =
              'No new Epic Games titles found. Install Epic Games Launcher games (or set HOMEDECK_EPIC_ROOT), then scan again.';
        } else if (added == 1) {
          _epicScanMessage =
              'Added 1 Epic title to Library. Open Library → By app → Epic.';
        } else {
          _epicScanMessage =
              'Added $added Epic titles to Library. Open Library → By app → Epic.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _epicScanBusy = false;
        _epicScanMessage = 'Epic scan failed: $error';
      });
    }
  }

  Future<void> _scanGogLibrary() async {
    if (_gogScanBusy) {
      return;
    }
    setState(() {
      _gogScanBusy = true;
      _gogScanMessage = null;
    });
    try {
      final added = await _library.importGog(pinToHome: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _gogScanBusy = false;
        if (added == 0) {
          _gogScanMessage =
              'No new GOG titles found. Install GOG Galaxy games (or set HOMEDECK_GOG_ROOT), then scan again.';
        } else if (added == 1) {
          _gogScanMessage =
              'Added 1 GOG title to Library. Open Library → By app → GOG.';
        } else {
          _gogScanMessage =
              'Added $added GOG titles to Library. Open Library → By app → GOG.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _gogScanBusy = false;
        _gogScanMessage = 'GOG scan failed: $error';
      });
    }
  }

  Future<void> _scanUbisoftLibrary() async {
    if (_ubisoftScanBusy) {
      return;
    }
    setState(() {
      _ubisoftScanBusy = true;
      _ubisoftScanMessage = null;
    });
    try {
      final added = await _library.importUbisoft(pinToHome: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _ubisoftScanBusy = false;
        if (added == 0) {
          _ubisoftScanMessage =
              'No new Ubisoft titles found. Install Ubisoft Connect games (or set HOMEDECK_UBISOFT_ROOT), then scan again.';
        } else if (added == 1) {
          _ubisoftScanMessage =
              'Added 1 Ubisoft title to Library. Open Library → By app → Ubisoft Connect.';
        } else {
          _ubisoftScanMessage =
              'Added $added Ubisoft titles to Library. Open Library → By app → Ubisoft Connect.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _ubisoftScanBusy = false;
        _ubisoftScanMessage = 'Ubisoft scan failed: $error';
      });
    }
  }

  Future<void> _scanEaLibrary() async {
    if (_eaScanBusy) {
      return;
    }
    setState(() {
      _eaScanBusy = true;
      _eaScanMessage = null;
    });
    try {
      final added = await _library.importEa(pinToHome: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _eaScanBusy = false;
        if (added == 0) {
          _eaScanMessage =
              'No new EA titles found. Install EA App / Origin games (or set HOMEDECK_EA_ROOT), then scan again.';
        } else if (added == 1) {
          _eaScanMessage =
              'Added 1 EA title to Library. Open Library → By app → Origin / EA app.';
        } else {
          _eaScanMessage =
              'Added $added EA titles to Library. Open Library → By app → Origin / EA app.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _eaScanBusy = false;
        _eaScanMessage = 'EA scan failed: $error';
      });
    }
  }

  void _onLibrary() {
    if (mounted) {
      setState(() {});
      _syncNativeFocusedLaunch();
    }
  }

  void _onWindowMode() {
    if (!mounted) {
      return;
    }
    setState(() {});
    // Native WM_KEYDOWN F11 toggles chrome in the runner and only notifies
    // Dart — persist window prefs so library.json mirrors chrome state.
    unawaited(_library.setWindowPrefs(_chromeWindowPrefs()));
  }

  /// Current chrome flags plus persisted launch / restore preferences.
  WindowPrefs _chromeWindowPrefs({
    bool? fullscreenOnLaunch,
    bool? restoreOnExit,
  }) {
    return WindowPrefs(
      fullscreen: _window.isFullscreen,
      borderless: _window.isBorderless,
      fullscreenOnLaunch:
          fullscreenOnLaunch ?? _library.state.window.fullscreenOnLaunch,
      restoreOnExit: restoreOnExit ?? _library.state.window.restoreOnExit,
    );
  }

  bool get _overlayOpen =>
      _failure != null ||
      _settingsOpen ||
      _detailsOpen ||
      _addOpen ||
      _menuOpen ||
      _searchOpen ||
      _pendingRemoveId != null;

  bool get _insideFolder => _tab == HomeTab.allApps && _folderTitle != null;

  bool get _dockVisible => !_insideFolder || _dockForced;

  void _click(UiClick kind) {
    _clicks.enabled = _library.state.audio.uiClicksEnabled;
    unawaited(_clicks.play(kind));
  }

  Map<ShortcutActivator, Intent> get _shortcuts => {
    const SingleActivator(LogicalKeyboardKey.enter):
        const LaunchFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter):
        const LaunchFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonA):
        const LaunchFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.delete):
        const RemoveFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace):
        const RemoveFocusedIntent(),
    const SingleActivator(LogicalKeyboardKey.escape):
        const DismissOverlayIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonB):
        const DismissOverlayIntent(),
    const SingleActivator(LogicalKeyboardKey.f11):
        const ToggleFullscreenIntent(),
    const SingleActivator(LogicalKeyboardKey.keyM):
        const ToggleMoveModeIntent(),
    const SingleActivator(LogicalKeyboardKey.keyA): const AddAppIntent(),
    const SingleActivator(LogicalKeyboardKey.keyS):
        const ScanSteamLibraryIntent(),
    const SingleActivator(LogicalKeyboardKey.keyP):
        const ScanStartMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.keyR):
        const ScanRomFolderIntent(),
    const SingleActivator(LogicalKeyboardKey.keyE):
        const ScanEpicLibraryIntent(),
    const SingleActivator(LogicalKeyboardKey.keyG):
        const ScanGogLibraryIntent(),
    const SingleActivator(LogicalKeyboardKey.keyU):
        const ScanUbisoftLibraryIntent(),
    const SingleActivator(LogicalKeyboardKey.keyO):
        const ScanEaLibraryIntent(),
    const SingleActivator(LogicalKeyboardKey.keyH):
        const PinFocusedToHomeIntent(),
    const SingleActivator(LogicalKeyboardKey.comma, control: true):
        const OpenSettingsIntent(),
    const SingleActivator(LogicalKeyboardKey.equal): const OpenMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.add): const OpenMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.minus): const OpenDetailsIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonStart):
        const OpenMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonSelect):
        const OpenDetailsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF):
        const ToggleFavoriteIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketLeft):
        const PrevTabIntent(),
    const SingleActivator(LogicalKeyboardKey.bracketRight):
        const NextTabIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonLeft1):
        const PrevTabIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonRight1):
        const NextTabIntent(),
    const SingleActivator(LogicalKeyboardKey.pageUp): const PrevTabIntent(),
    const SingleActivator(LogicalKeyboardKey.pageDown): const NextTabIntent(),
    const SingleActivator(LogicalKeyboardKey.keyX):
        const ToggleLibraryGroupIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonX):
        const ToggleLibraryGroupIntent(),
    const SingleActivator(LogicalKeyboardKey.keyY): const OpenSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonY):
        const OpenSearchIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft):
        const DirectionalFocusIntent(TraversalDirection.left),
    const SingleActivator(LogicalKeyboardKey.arrowRight):
        const DirectionalFocusIntent(TraversalDirection.right),
    const SingleActivator(LogicalKeyboardKey.arrowUp):
        const DirectionalFocusIntent(TraversalDirection.up),
    const SingleActivator(LogicalKeyboardKey.arrowDown):
        const DirectionalFocusIntent(TraversalDirection.down),
  };

  Map<Type, Action<Intent>> _actions(HomeDeckMetrics metrics) {
    return {
      LaunchFocusedIntent: CallbackAction<LaunchFocusedIntent>(
        onInvoke: (_) {
          _handleConfirm();
          return null;
        },
      ),
      ConfirmIntent: CallbackAction<ConfirmIntent>(
        onInvoke: (_) {
          _handleConfirm();
          return null;
        },
      ),
      RemoveFocusedIntent: CallbackAction<RemoveFocusedIntent>(
        onInvoke: (_) {
          _requestRemove();
          return null;
        },
      ),
      AddAppIntent: CallbackAction<AddAppIntent>(
        onInvoke: (_) {
          _addApp();
          return null;
        },
      ),
      ScanSteamLibraryIntent: CallbackAction<ScanSteamLibraryIntent>(
        onInvoke: (_) {
          unawaited(_scanSteamLibrary());
          return null;
        },
      ),
      ScanStartMenuIntent: CallbackAction<ScanStartMenuIntent>(
        onInvoke: (_) {
          unawaited(_scanStartMenu());
          return null;
        },
      ),
      ScanRomFolderIntent: CallbackAction<ScanRomFolderIntent>(
        onInvoke: (_) {
          unawaited(_scanRomFolder());
          return null;
        },
      ),
      ScanEpicLibraryIntent: CallbackAction<ScanEpicLibraryIntent>(
        onInvoke: (_) {
          unawaited(_scanEpicLibrary());
          return null;
        },
      ),
      ScanGogLibraryIntent: CallbackAction<ScanGogLibraryIntent>(
        onInvoke: (_) {
          unawaited(_scanGogLibrary());
          return null;
        },
      ),
      ScanUbisoftLibraryIntent: CallbackAction<ScanUbisoftLibraryIntent>(
        onInvoke: (_) {
          unawaited(_scanUbisoftLibrary());
          return null;
        },
      ),
      ScanEaLibraryIntent: CallbackAction<ScanEaLibraryIntent>(
        onInvoke: (_) {
          unawaited(_scanEaLibrary());
          return null;
        },
      ),
      PinFocusedToHomeIntent: CallbackAction<PinFocusedToHomeIntent>(
        onInvoke: (_) {
          unawaited(_pinFocusedToHome());
          return null;
        },
      ),
      ToggleMoveModeIntent: CallbackAction<ToggleMoveModeIntent>(
        onInvoke: (_) {
          if (_tab == HomeTab.home) {
            setState(() => _moveMode = !_moveMode);
          }
          return null;
        },
      ),
      ToggleFullscreenIntent: CallbackAction<ToggleFullscreenIntent>(
        onInvoke: (_) {
          _toggleFullscreen();
          return null;
        },
      ),
      ToggleBorderlessIntent: CallbackAction<ToggleBorderlessIntent>(
        onInvoke: (_) {
          _toggleBorderless();
          return null;
        },
      ),
      OpenSettingsIntent: CallbackAction<OpenSettingsIntent>(
        onInvoke: (_) {
          setState(() => _settingsOpen = true);
          return null;
        },
      ),
      OpenMenuIntent: CallbackAction<OpenMenuIntent>(
        onInvoke: (_) {
          setState(() => _menuOpen = true);
          return null;
        },
      ),
      ToggleLibraryGroupIntent: CallbackAction<ToggleLibraryGroupIntent>(
        onInvoke: (_) {
          _toggleLibraryGroup();
          return null;
        },
      ),
      OpenDetailsIntent: CallbackAction<OpenDetailsIntent>(
        onInvoke: (_) {
          _openDetails();
          return null;
        },
      ),
      NextTabIntent: CallbackAction<NextTabIntent>(
        onInvoke: (_) {
          _shiftTab(1);
          return null;
        },
      ),
      PrevTabIntent: CallbackAction<PrevTabIntent>(
        onInvoke: (_) {
          _shiftTab(-1);
          return null;
        },
      ),
      OpenSearchIntent: CallbackAction<OpenSearchIntent>(
        onInvoke: (_) {
          _openSearch();
          return null;
        },
      ),
      DismissOverlayIntent: CallbackAction<DismissOverlayIntent>(
        onInvoke: (_) {
          _dismiss();
          return null;
        },
      ),
      ToggleFavoriteIntent: CallbackAction<ToggleFavoriteIntent>(
        onInvoke: (_) {
          final id = _focusedId;
          if (id != null &&
              id != addTileId &&
              !isEmptySlotId(id) &&
              !isNowPlayingId(id) &&
              !isFolderFocusId(id)) {
            _library.toggleFavorite(id);
          }
          return null;
        },
      ),
      DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(
        onInvoke: (intent) {
          _onDirection(intent.direction, metrics);
          return null;
        },
      ),
    };
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (_gamepad.isConnected && _isGamepadKey(event.logicalKey)) {
      return true;
    }
    // Ally Phase2 sends Enter/F11 to the focused HWND. When Shortcuts do not
    // see a focused FocusNode after sheet teardown, still launch or toggle
    // chrome. Leave Enter alone while an overlay is open so Add/Confirm
    // Actions keep working.
    final key = event.logicalKey;
    if (!_overlayOpen &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      _handleConfirm();
      return true;
    }
    if (key == LogicalKeyboardKey.f11) {
      unawaited(_toggleFullscreen());
      return true;
    }
    return false;
  }

  bool _isGamepadKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.gameButtonB ||
        key == LogicalKeyboardKey.gameButtonX ||
        key == LogicalKeyboardKey.gameButtonY ||
        key == LogicalKeyboardKey.gameButtonLeft1 ||
        key == LogicalKeyboardKey.gameButtonRight1 ||
        key == LogicalKeyboardKey.gameButtonStart ||
        key == LogicalKeyboardKey.gameButtonSelect;
  }

  void _onGamepad(GamepadButton button) {
    if (!mounted) {
      return;
    }
    final metrics = HomeDeckMetrics.of(MediaQuery.sizeOf(context));
    switch (button) {
      case GamepadButton.a:
        _handleConfirm();
      case GamepadButton.b:
        _dismiss();
      case GamepadButton.lb:
        _shiftTab(-1);
      case GamepadButton.rb:
        _shiftTab(1);
      case GamepadButton.start:
        setState(() => _menuOpen = true);
      case GamepadButton.back:
        _openDetails();
      case GamepadButton.dpadLeft:
        _onDirection(TraversalDirection.left, metrics);
      case GamepadButton.dpadRight:
        _onDirection(TraversalDirection.right, metrics);
      case GamepadButton.dpadUp:
        _onDirection(TraversalDirection.up, metrics);
      case GamepadButton.dpadDown:
        _onDirection(TraversalDirection.down, metrics);
      case GamepadButton.x:
        _toggleLibraryGroup();
      case GamepadButton.y:
        _openSearch();
      case GamepadButton.lt:
      case GamepadButton.rt:
        break;
    }
  }

  void _shiftTab(int delta) {
    if (_overlayOpen) {
      return;
    }
    final values = HomeTab.values;
    final next = (values.indexOf(_tab) + delta) % values.length;
    _click(UiClick.page);
    setState(() {
      _tab = values[next < 0 ? values.length - 1 : next];
      _dockForced = true;
      _folderTitle = null;
      _chipsFocused = false;
    });
    _focusFirstForTab();
  }

  void _focusFirstForTab() {
    if (_tab == HomeTab.home) {
      // Prefer an already-focused Home pin (Ally H pin → UIA dock Home) so
      // Now Playing does not clear the mirrored launch path before Enter.
      final id = _focusedId;
      if (id != null &&
          !isNowPlayingId(id) &&
          !isEmptySlotId(id) &&
          !isFolderFocusId(id) &&
          _library.isOnHome(id)) {
        _focusId(id, click: false);
        return;
      }
      _focusId(nowPlayingId, click: false);
      return;
    }
    if (_tab == HomeTab.allApps) {
      final metrics = HomeDeckMetrics.of(MediaQuery.sizeOf(context));
      final ids = _gridFocusableIds(metrics);
      if (ids.isNotEmpty) {
        _focusId(ids.first, click: false);
      }
    }
  }

  void _openSearch() {
    if (_failure != null || _pendingRemoveId != null) {
      return;
    }
    setState(() => _searchOpen = true);
  }

  Future<void> _toggleFullscreen() async {
    await _window.toggleFullscreen();
    await _library.setWindowPrefs(_chromeWindowPrefs());
  }

  Future<void> _toggleBorderless() async {
    await _window.toggleBorderless();
    await _library.setWindowPrefs(_chromeWindowPrefs());
  }

  Future<void> _setFullscreenOnLaunch(bool enabled) async {
    await _library.setWindowPrefs(
      _chromeWindowPrefs(fullscreenOnLaunch: enabled),
    );
    if (Platform.isWindows) {
      await WindowsNativeBridge.setFullscreenOnLaunch(enabled);
    }
  }

  Future<void> _setRestoreOnExit(bool enabled) async {
    await _library.setWindowPrefs(_chromeWindowPrefs(restoreOnExit: enabled));
    if (Platform.isWindows) {
      await WindowsNativeBridge.setRestoreOnExit(enabled);
    }
  }

  /// Same chrome path as F11 after a successful Home / Library launch.
  Future<void> _enterFullscreenOnLaunchIfEnabled() async {
    if (!_library.state.window.fullscreenOnLaunch) {
      return;
    }
    if (_window.isFullscreen) {
      return;
    }
    await _window.apply(true, _window.isBorderless);
    await _library.setWindowPrefs(_chromeWindowPrefs());
  }

  /// Runner waited on a tracked local process and restored chrome/foreground.
  Future<void> _gameExitedFromNative() async {
    if (!mounted) {
      return;
    }
    await widget.music?.unduck();
    await _library.setWindowPrefs(_chromeWindowPrefs());
    if (mounted) {
      setState(() {});
    }
  }

  void _handleConfirm() {
    final now = DateTime.now();
    if (now.difference(_lastConfirm) < const Duration(milliseconds: 220)) {
      return;
    }
    _lastConfirm = now;
    if (_failure != null) {
      setState(() {
        _failure = null;
        _failureApp = null;
      });
      return;
    }
    if (_pendingRemoveId != null) {
      final id = _pendingRemoveId!;
      setState(() => _pendingRemoveId = null);
      _library.remove(id);
      unawaited(_clearRemoveArmedAndSyncLaunch());
      return;
    }
    if (_searchOpen) {
      return;
    }
    if (_menuOpen) {
      setState(() => _menuOpen = false);
      return;
    }
    if (_settingsOpen) {
      setState(() => _settingsOpen = false);
      return;
    }
    if (_addOpen) {
      return;
    }
    if (_detailsOpen) {
      setState(() => _detailsOpen = false);
      return;
    }
    if (_moveMode) {
      setState(() => _moveMode = false);
      return;
    }
    if (_tab != HomeTab.home && _tab != HomeTab.allApps) {
      return;
    }
    if (_focusedId == addTileId || isEmptySlotId(_focusedId ?? '')) {
      _click(UiClick.select);
      _addApp();
      return;
    }
    if (isNowPlayingId(_focusedId ?? '')) {
      _click(UiClick.select);
      unawaited(widget.music?.togglePause());
      return;
    }
    if (isFolderFocusId(_focusedId ?? '')) {
      final title = _folderTitleForFocus(_focusedId!);
      if (title != null) {
        _click(UiClick.select);
        _openFolder(title);
      }
      return;
    }
    final focused = _focusedRecord;
    if (focused != null) {
      _click(UiClick.select);
      _launch(focused);
    }
  }

  Future<void> _clearRemoveArmedAndSyncLaunch() async {
    await WindowsNativeBridge.setRemoveArmed(false);
    if (!mounted) {
      return;
    }
    _syncNativeFocusedLaunch();
  }

  void _dismiss() {
    if (_failure != null) {
      setState(() {
        _failure = null;
        _failureApp = null;
      });
      return;
    }
    if (_pendingRemoveId != null) {
      setState(() => _pendingRemoveId = null);
      unawaited(_clearRemoveArmedAndSyncLaunch());
      return;
    }
    if (_searchOpen) {
      _click(UiClick.back);
      setState(() => _searchOpen = false);
      return;
    }
    if (_menuOpen) {
      _click(UiClick.back);
      setState(() => _menuOpen = false);
      return;
    }
    if (_settingsOpen) {
      _click(UiClick.back);
      setState(() => _settingsOpen = false);
      return;
    }
    if (_addOpen) {
      _click(UiClick.back);
      setState(() => _addOpen = false);
      return;
    }
    if (_detailsOpen) {
      _click(UiClick.back);
      setState(() => _detailsOpen = false);
      return;
    }
    if (_moveMode) {
      _click(UiClick.back);
      setState(() => _moveMode = false);
      return;
    }
    if (_insideFolder) {
      _click(UiClick.back);
      _closeFolder();
    }
  }

  void _openDetails() {
    if (_overlayOpen) {
      return;
    }
    if (_focusedRecord == null &&
        !isNowPlayingId(_focusedId ?? '') &&
        !isFolderFocusId(_focusedId ?? '') &&
        !isEmptySlotId(_focusedId ?? '')) {
      return;
    }
    setState(() => _detailsOpen = true);
  }

  AppRecord? get _focusedRecord {
    final id = _focusedId;
    if (id == null ||
        id == addTileId ||
        isEmptySlotId(id) ||
        isNowPlayingId(id) ||
        isFolderFocusId(id)) {
      return null;
    }
    return _library.byId(id);
  }

  String get _selectedTitle {
    if (_searchOpen) {
      return 'Search';
    }
    if (_focusedId == addTileId) {
      return 'Add app';
    }
    if (isEmptySlotId(_focusedId ?? '')) {
      return 'Empty slot';
    }
    if (isNowPlayingId(_focusedId ?? '')) {
      return widget.music?.currentTitle ?? 'Now playing';
    }
    if (isFolderFocusId(_focusedId ?? '')) {
      return _folderTitleForFocus(_focusedId!) ?? 'Folder';
    }
    if (_insideFolder && _focusedRecord == null) {
      return _folderTitle ?? 'Library';
    }
    return _focusedRecord?.displayName ??
        _folderTitle ??
        (_tab == HomeTab.home
            ? 'Home'
            : _tab == HomeTab.allApps
            ? 'Library'
            : 'HomeDeck');
  }

  Future<void> _launch(AppRecord app) async {
    if (_moveMode) {
      setState(() => _moveMode = false);
      return;
    }
    final outcome = await _library.launch(app.id);
    if (!mounted) {
      return;
    }
    if (outcome is LaunchSuccess) {
      await widget.music?.duck();
      await _enterFullscreenOnLaunchIfEnabled();
      return;
    }
    if (outcome is LaunchFailure) {
      setState(() {
        _failure = outcome;
        _failureApp = app.displayName;
      });
    }
  }

  Future<void> _addApp() async {
    if (_overlayOpen) {
      return;
    }
    if (Platform.isWindows) {
      // Ally Phase2: SendKeys 'a' is handled by WH_KEYBOARD_LL → WM_HOMEDECK_ADD
      // → runner GetOpenFileName → addPickedPath (see _addPickedPathFromNative).
      // Empty Add slots / Menu paths still one-shot pick here so tiles land
      // without Confirm on an in-app sheet. @82a5a20 failed because Shortcuts
      // never saw `a`, so this path never ran under the harness.
      final added = await _library.addFromPicker();
      if (!mounted || added == null) {
        return;
      }
      await _focusAddedApp(added);
      return;
    }
    setState(() => _addOpen = true);
    // Clear runner Enter target while the Add sheet owns Enter / Confirm.
    _syncNativeFocusedLaunch();
  }

  void _requestRemove() {
    final id = _focusedId;
    if (id == null ||
        id == addTileId ||
        isEmptySlotId(id) ||
        isNowPlayingId(id) ||
        isFolderFocusId(id)) {
      return;
    }
    if (_tab == HomeTab.home) {
      _library.unpinFromHome(id);
      return;
    }
    setState(() => _pendingRemoveId = id);
    // Clear Enter mirror so confirm cannot ShellExecute the focused path.
    _syncNativeFocusedLaunch();
  }

  void _openFolder(String title) {
    final section = _sectionByTitle(title);
    setState(() {
      _folderTitle = title;
      _dockForced = false;
      _chipsFocused = false;
      if (section != null && section.apps.isNotEmpty) {
        _focusedId = section.apps.first.id;
      }
    });
    final id = _focusedId;
    if (id != null) {
      _nodeFor(id).requestFocus();
    }
  }

  void _closeFolder() {
    final title = _folderTitle;
    setState(() {
      _folderTitle = null;
      _dockForced = false;
      if (title != null) {
        _focusedId = folderFocusId(title);
      }
    });
    final id = _focusedId;
    if (id != null) {
      _nodeFor(id).requestFocus();
    }
  }

  LibrarySection? _sectionByTitle(String title) {
    for (final section in _library.librarySections(_libraryMode)) {
      if (section.title == title) {
        return section;
      }
    }
    return null;
  }

  String? _folderTitleForFocus(String id) {
    for (final section in _library.librarySections(_libraryMode)) {
      if (folderFocusId(section.title) == id) {
        return section.title;
      }
    }
    return null;
  }

  void _onReorderDrop(String draggedId, String ontoId) {
    final from = _library.home.indexOf(draggedId);
    final to = isEmptySlotId(ontoId)
        ? emptySlotIndex(ontoId)
        : _library.home.indexOf(ontoId);
    if (from != null && to != null) {
      _library.swapHomeSlots(from, to);
    }
  }

  void _toggleLibraryGroup() {
    if (_overlayOpen || _tab != HomeTab.allApps || _insideFolder) {
      return;
    }
    setState(() {
      _libraryMode = _libraryMode == LibraryGroupMode.console
          ? LibraryGroupMode.store
          : LibraryGroupMode.console;
      _focusedId = null;
    });
    _focusFirstForTab();
  }

  void _onDirection(TraversalDirection direction, HomeDeckMetrics metrics) {
    if (_overlayOpen) {
      return;
    }
    if (_moveMode && _tab == HomeTab.home) {
      _nudgeHomeTile(direction, metrics);
      return;
    }
    _moveSelection(direction, metrics);
  }

  void _nudgeHomeTile(TraversalDirection direction, HomeDeckMetrics metrics) {
    final from = _homeIndexOfFocused();
    if (from == null) {
      return;
    }
    final cols = HomePager.columns(_page, metrics);
    final to = switch (direction) {
      TraversalDirection.left => from - 1,
      TraversalDirection.right => from + 1,
      TraversalDirection.up => from - cols,
      TraversalDirection.down => from + cols,
    };
    if (to < 0) {
      return;
    }
    _library.moveHomeSlot(from, direction, cols);
    final id = _library.home[to] ?? emptySlotId(to);
    _focusId(id);
  }

  int? _homeIndexOfFocused() {
    final id = _focusedId;
    if (id == null) {
      return null;
    }
    if (isEmptySlotId(id)) {
      return emptySlotIndex(id);
    }
    return _library.home.indexOf(id);
  }

  List<String> _gridFocusableIds(HomeDeckMetrics metrics) {
    if (_tab == HomeTab.allApps) {
      if (_insideFolder) {
        final section = _sectionByTitle(_folderTitle!);
        return [for (final app in section?.apps ?? const <AppRecord>[]) app.id];
      }
      return [
        for (final section in _library.librarySections(_libraryMode))
          folderFocusId(section.title),
        addTileId,
      ];
    }
    final pages = _pageCount(metrics);
    final slots = _library.homeSlots(
      minLength: HomePager.slotCount(pages, metrics),
    );
    return [
      for (var page = 0; page < pages; page++)
        ...HomePager.focusIdsForPage(
          page: page,
          slots: slots,
          metrics: metrics,
        ),
    ];
  }

  List<String> _pageFocusIds(int page, HomeDeckMetrics metrics) {
    final pages = _pageCount(metrics);
    final slots = _library.homeSlots(
      minLength: HomePager.slotCount(pages, metrics),
    );
    return HomePager.focusIdsForPage(
      page: page,
      slots: slots,
      metrics: metrics,
    );
  }

  FocusNode _nodeFor(String id) {
    return _focusNodes.putIfAbsent(id, FocusNode.new);
  }

  int _pageCount(HomeDeckMetrics metrics) {
    if (_tab == HomeTab.allApps) {
      return 1;
    }
    return HomePager.pageCount(
      lastOccupiedIndex: _library.home.lastOccupiedIndex,
      metrics: metrics,
      extraPages: _extraHomePages,
    );
  }

  void _focusId(String id, {bool click = true}) {
    final metrics = HomeDeckMetrics.of(MediaQuery.sizeOf(context));
    if (click && id != _focusedId) {
      _click(UiClick.move);
    }
    setState(() {
      _focusedId = id;
      if (_tab == HomeTab.home) {
        if (isNowPlayingId(id)) {
          _page = 0;
        } else {
          final slot = isEmptySlotId(id)
              ? emptySlotIndex(id)
              : _library.home.indexOf(id);
          if (slot != null) {
            _page = HomePager.pageOfSlot(slot, metrics);
          }
        }
      }
    });
    _nodeFor(id).requestFocus();
    _syncNativeFocusedLaunch();
  }

  /// Mirror the focused exe/lnk/URI into the runner so Ally SendKeys Enter
  /// can ShellExecute without a Flutter KeyEvent (WH_KEYBOARD_LL path).
  void _syncNativeFocusedLaunch() {
    if (!Platform.isWindows) {
      return;
    }
    if (_overlayOpen) {
      // Clear so Add-sheet Enter confirms instead of re-launching a prior tile.
      unawaited(WindowsNativeBridge.setFocusedLaunch(null));
      return;
    }
    final app = _focusedRecord;
    if (app == null) {
      unawaited(WindowsNativeBridge.setFocusedLaunch(null));
      return;
    }
    final target =
        app.targetFor(AppPlatform.windows) ?? app.targets[AppPlatform.windows];
    if (target == null) {
      unawaited(WindowsNativeBridge.setFocusedLaunch(null));
      return;
    }
    unawaited(
      WindowsNativeBridge.setFocusedLaunch(
        target.value,
        arguments: target.resolvedArguments,
      ),
    );
  }

  Future<void> _syncNativeFocusedLaunchAwait() async {
    if (!Platform.isWindows) {
      return;
    }
    final app = _focusedRecord;
    if (app == null) {
      await WindowsNativeBridge.setFocusedLaunch(null);
      return;
    }
    final target =
        app.targetFor(AppPlatform.windows) ?? app.targets[AppPlatform.windows];
    if (target == null) {
      await WindowsNativeBridge.setFocusedLaunch(null);
      return;
    }
    await WindowsNativeBridge.setFocusedLaunch(
      target.value,
      arguments: target.resolvedArguments,
    );
  }

  void _goToPage(int page, {int? row, bool fromRight = false}) {
    final metrics = HomeDeckMetrics.of(MediaQuery.sizeOf(context));
    final pages = _pageCount(metrics);
    final next = page.clamp(0, pages - 1);
    final slots = _library.homeSlots(
      minLength: HomePager.slotCount(pages, metrics),
    );
    final id = HomePager.focusedIdAfterPageChange(
      page: next,
      slots: slots,
      metrics: metrics,
      row: row,
      fromRight: fromRight,
    );
    _click(UiClick.page);
    setState(() => _page = next);
    _focusId(id, click: false);
  }

  void _moveSelection(TraversalDirection direction, HomeDeckMetrics metrics) {
    if (_tab == HomeTab.home) {
      _moveHome(direction, metrics);
      return;
    }
    if (_tab == HomeTab.allApps && _chipsFocused) {
      if (direction == TraversalDirection.left ||
          direction == TraversalDirection.right) {
        _toggleLibraryGroup();
      } else if (direction == TraversalDirection.down) {
        setState(() => _chipsFocused = false);
        final ids = _gridFocusableIds(metrics);
        if (ids.isNotEmpty) {
          _focusId(ids.first);
        }
      }
      return;
    }
    final ids = _gridFocusableIds(metrics);
    if (ids.isEmpty) {
      return;
    }
    var index = ids.indexOf(_focusedId ?? ids.first);
    if (index < 0) {
      index = 0;
    }
    final columns = _insideFolder
        ? metrics.insideFolderColumns
        : metrics.libraryFolderColumns;
    final next = switch (direction) {
      TraversalDirection.left => index - 1,
      TraversalDirection.right => index + 1,
      TraversalDirection.up => index - columns,
      TraversalDirection.down => index + columns,
    };
    if (next < 0) {
      if (_tab == HomeTab.allApps &&
          !_insideFolder &&
          direction == TraversalDirection.up) {
        setState(() => _chipsFocused = true);
        return;
      }
      return;
    }
    if (next >= ids.length) {
      if (_insideFolder && direction == TraversalDirection.down) {
        setState(() => _dockForced = true);
      }
      return;
    }
    if (_insideFolder &&
        direction == TraversalDirection.down &&
        next ~/ columns >= (ids.length / columns).ceil() - 1) {
      setState(() => _dockForced = true);
    }
    _focusId(ids[next]);
  }

  void _moveHome(TraversalDirection direction, HomeDeckMetrics metrics) {
    final pages = _pageCount(metrics);
    final page = _page.clamp(0, pages - 1);
    final ids = _pageFocusIds(page, metrics);
    if (ids.isEmpty) {
      return;
    }
    var index = ids.indexOf(_focusedId ?? ids.first);
    if (index < 0) {
      index = 0;
    }
    final cols = HomePager.columns(page, metrics);
    if (page == 0) {
      if (index == 0) {
        if (direction == TraversalDirection.right) {
          _focusId(ids[1]);
        }
        return;
      }
      final pin = index - 1;
      final row = pin ~/ cols;
      final col = pin % cols;
      if (direction == TraversalDirection.left && col == 0) {
        _focusId(nowPlayingId);
        return;
      }
      if (direction == TraversalDirection.right && col == cols - 1) {
        if (page < pages - 1) {
          _goToPage(page + 1, row: row);
        }
        return;
      }
      final nextPin = switch (direction) {
        TraversalDirection.left => pin - 1,
        TraversalDirection.right => pin + 1,
        TraversalDirection.up => pin - cols,
        TraversalDirection.down => pin + cols,
      };
      if (nextPin < 0 || nextPin >= cols * metrics.rows) {
        return;
      }
      _focusId(ids[nextPin + 1]);
      return;
    }
    final row = index ~/ cols;
    final col = index % cols;
    if (direction == TraversalDirection.left && col == 0) {
      _goToPage(page - 1, row: row, fromRight: true);
      return;
    }
    if (direction == TraversalDirection.right && col == cols - 1) {
      if (page < pages - 1) {
        _goToPage(page + 1, row: row);
      }
      return;
    }
    final next = switch (direction) {
      TraversalDirection.left => index - 1,
      TraversalDirection.right => index + 1,
      TraversalDirection.up => index - cols,
      TraversalDirection.down => index + cols,
    };
    if (next < 0 || next >= ids.length) {
      return;
    }
    _focusId(ids[next]);
  }

  int _displayPage(HomeDeckMetrics metrics) {
    return _page.clamp(0, _pageCount(metrics) - 1);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final metrics = HomeDeckMetrics.of(size);
    final pages = _pageCount(metrics);
    final page = _displayPage(metrics);
    final focused = _focusedRecord;
    final File? artFile = focused == null ? null : _library.iconFile(focused);

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: _actions(metrics),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: Stack(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: ArtBackdrop(
                      key: ValueKey(
                        _tab == HomeTab.allApps
                            ? 'library-home'
                            : (_focusedId ?? 'none'),
                      ),
                      color: _tab == HomeTab.allApps
                          ? backdropColorFor(nowPlayingId)
                          : backdropColorFor(_focusedId ?? 'home'),
                      imageFile: _tab == HomeTab.allApps ? null : artFile,
                    ),
                  ),
                  Column(
                    children: [
                      HomeTopBar(
                        metrics: metrics,
                        title: _selectedTitle,
                        now: _now,
                        batteryPercent: _status.batteryPercent,
                        fullscreen: _window.isFullscreen,
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                _tab == HomeTab.home || _tab == HomeTab.allApps
                                ? (_insideFolder ? 0 : 12 * metrics.scale)
                                : 36 * metrics.scale,
                            vertical: 4 * metrics.scale,
                          ),
                          child: _tab == HomeTab.home || _tab == HomeTab.allApps
                              ? _tabBody(metrics, page, pages)
                              : GlassPanel(
                                  child: _tabBody(metrics, page, pages),
                                ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        child: _dockVisible
                            ? Padding(
                                padding: EdgeInsets.only(
                                  top: 8 * metrics.scale,
                                  bottom: 52 * metrics.scale,
                                ),
                                child: TabDock(
                                  metrics: metrics,
                                  active: _tab,
                                  onSelect: (tab) {
                                    setState(() {
                                      _tab = tab;
                                      _folderTitle = null;
                                      _dockForced = true;
                                    });
                                    _focusFirstForTab();
                                  },
                                  onSearch: _openSearch,
                                ),
                              )
                            : SizedBox(height: 52 * metrics.scale),
                      ),
                    ],
                  ),
                  CornerHints(
                    metrics: metrics,
                    onBack: _dismiss,
                    onDetails: _openDetails,
                    onSelect: _handleConfirm,
                    onMenu: () => setState(() => _menuOpen = true),
                  ),
                  if (_failure != null)
                    LaunchErrorView(
                      key: const Key('launch-error-dialog'),
                      failure: _failure!,
                      appName: _failureApp ?? 'This app',
                      scale: metrics.scale,
                      onDismiss: _dismiss,
                    ),
                  if (_menuOpen)
                    TileMenu(
                      scale: metrics.scale,
                      title: _tab == HomeTab.home
                          ? 'Customize Home'
                          : _selectedTitle,
                      app: focused,
                      onHome: _tab == HomeTab.home,
                      pinned: focused != null && _library.isOnHome(focused.id),
                      onClose: () => setState(() => _menuOpen = false),
                      onAddGame: () {
                        setState(() {
                          _menuOpen = false;
                          _addOpen = true;
                        });
                        _syncNativeFocusedLaunch();
                      },
                      onSearch: () {
                        setState(() {
                          _menuOpen = false;
                          _searchOpen = true;
                        });
                      },
                      onReorder: _tab != HomeTab.home
                          ? null
                          : () {
                              setState(() {
                                _menuOpen = false;
                                _moveMode = true;
                              });
                            },
                      onNewPage: _tab != HomeTab.home
                          ? null
                          : () {
                              setState(() {
                                _menuOpen = false;
                                _extraHomePages += 1;
                              });
                            },
                      onSettings: () {
                        setState(() {
                          _menuOpen = false;
                          _settingsOpen = true;
                        });
                      },
                      onExit: () => _window.close(),
                      onAddToHome: focused == null
                          ? null
                          : () {
                              _library.pinToHome(focused.id);
                              setState(() => _menuOpen = false);
                            },
                      onRemoveFromHome: focused == null
                          ? null
                          : () {
                              _library.unpinFromHome(focused.id);
                              setState(() => _menuOpen = false);
                            },
                      onMove: focused == null || _tab != HomeTab.home
                          ? null
                          : () {
                              setState(() {
                                _menuOpen = false;
                                _moveMode = true;
                              });
                            },
                      onDetails: focused == null
                          ? null
                          : () {
                              setState(() {
                                _menuOpen = false;
                                _detailsOpen = true;
                              });
                            },
                      onRemoveFromLibrary: focused == null
                          ? null
                          : () {
                              setState(() {
                                _menuOpen = false;
                                _pendingRemoveId = focused.id;
                              });
                              _syncNativeFocusedLaunch();
                            },
                    ),
                  if (_addOpen)
                    AddTileSheet(
                      controller: _library,
                      scale: metrics.scale,
                      onClose: () => setState(() => _addOpen = false),
                      onAdded: (id) {
                        // Set focused id synchronously so Enter via
                        // HardwareKeyboard / runner hook launches even if
                        // FocusNode is not attached yet. Await the mirror so
                        // Ally SendKeys Enter cannot race an empty path.
                        setState(() {
                          _addOpen = false;
                          _focusedId = id;
                        });
                        unawaited(_syncNativeFocusedLaunchAwait());
                        // Focus after the sheet leaves the tree and the new
                        // Home pin is built; requestFocus on a detached node
                        // was leaving keyboard focus on Now Playing.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          _focusId(id);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) {
                              return;
                            }
                            _nodeFor(id).requestFocus();
                            unawaited(_syncNativeFocusedLaunchAwait());
                          });
                        });
                      },
                    ),
                  if (_searchOpen)
                    GlobalSearchSheet(
                      controller: _library,
                      mode: _libraryMode,
                      scale: metrics.scale,
                      onClose: () => setState(() => _searchOpen = false),
                      onOpenFolder: (title) {
                        setState(() {
                          _searchOpen = false;
                          _tab = HomeTab.allApps;
                        });
                        _openFolder(title);
                      },
                      onOpenApp: (app) {
                        setState(() => _searchOpen = false);
                        _focusId(app.id, click: false);
                        _launch(app);
                      },
                    ),
                  if (_settingsOpen)
                    SettingsStub(
                      windowMode: _window,
                      scale: metrics.scale,
                      fullscreenOnLaunch:
                          _library.state.window.fullscreenOnLaunch,
                      onFullscreenOnLaunch: (enabled) {
                        unawaited(_setFullscreenOnLaunch(enabled));
                      },
                      restoreOnExit: _library.state.window.restoreOnExit,
                      onRestoreOnExit: (enabled) {
                        unawaited(_setRestoreOnExit(enabled));
                      },
                      musicEnabled:
                          widget.music?.musicEnabled ??
                          _library.state.audio.musicEnabled,
                      musicVolume:
                          widget.music?.musicVolume ??
                          _library.state.audio.musicVolume,
                      uiClicksEnabled: _library.state.audio.uiClicksEnabled,
                      steamScanBusy: _steamScanBusy,
                      steamScanMessage: _steamScanMessage,
                      onScanSteam: _scanSteamLibrary,
                      startMenuScanBusy: _startMenuScanBusy,
                      startMenuScanMessage: _startMenuScanMessage,
                      onScanStartMenu: _scanStartMenu,
                      romRoot: _library.state.romRoot,
                      onPickRomRoot: () {
                        unawaited(_pickRomRoot());
                      },
                      onScanRoms: _scanRomFolder,
                      romScanBusy: _romScanBusy,
                      romScanMessage: _romScanMessage,
                      epicScanBusy: _epicScanBusy,
                      epicScanMessage: _epicScanMessage,
                      onScanEpic: _scanEpicLibrary,
                      gogScanBusy: _gogScanBusy,
                      gogScanMessage: _gogScanMessage,
                      onScanGog: _scanGogLibrary,
                      ubisoftScanBusy: _ubisoftScanBusy,
                      ubisoftScanMessage: _ubisoftScanMessage,
                      onScanUbisoft: _scanUbisoftLibrary,
                      eaScanBusy: _eaScanBusy,
                      eaScanMessage: _eaScanMessage,
                      onScanEa: _scanEaLibrary,
                      onClose: () => setState(() {
                        _settingsOpen = false;
                        _steamScanMessage = null;
                        _startMenuScanMessage = null;
                        _romScanMessage = null;
                        _epicScanMessage = null;
                        _gogScanMessage = null;
                        _ubisoftScanMessage = null;
                        _eaScanMessage = null;
                      }),
                      onToggleFullscreen: _toggleFullscreen,
                      onToggleBorderless: _toggleBorderless,
                      onUiClicksEnabled: (enabled) {
                        _library.setAudioPrefs(
                          _library.state.audio.copyWith(
                            uiClicksEnabled: enabled,
                          ),
                        );
                      },
                      onMusicEnabled: (enabled) {
                        final music = widget.music;
                        if (music != null) {
                          music.setEnabled(enabled);
                        } else {
                          _library.setAudioPrefs(
                            _library.state.audio.copyWith(
                              musicEnabled: enabled,
                            ),
                          );
                        }
                      },
                      onMusicVolume: (volume) {
                        final music = widget.music;
                        if (music != null) {
                          music.setVolume(volume);
                        } else {
                          _library.setAudioPrefs(
                            _library.state.audio.copyWith(musicVolume: volume),
                          );
                        }
                      },
                      onExit: () async {
                        await widget.music?.fadeOutAndStop();
                        await _window.close();
                      },
                    ),
                  if (_detailsOpen)
                    _DetailsSheet(
                      name: _selectedTitle,
                      kindLabel: focused?.kind.wireName,
                      path: focused == null || focused.targets.isEmpty
                          ? null
                          : focused.targets.values.first.value,
                      romPath: focused == null || focused.targets.isEmpty
                          ? null
                          : focused.targets.values.first.romPath,
                      scale: metrics.scale,
                      onClose: () => setState(() => _detailsOpen = false),
                      onAddToHome:
                          focused == null || _library.isOnHome(focused.id)
                          ? null
                          : () {
                              _library.pinToHome(focused.id);
                              setState(() => _detailsOpen = false);
                            },
                      onRemoveFromHome:
                          focused == null || !_library.isOnHome(focused.id)
                          ? null
                          : () {
                              _library.unpinFromHome(focused.id);
                              setState(() => _detailsOpen = false);
                            },
                      onRemove: focused == null
                          ? null
                          : () {
                              setState(() {
                                _detailsOpen = false;
                                _pendingRemoveId = focused.id;
                              });
                              _syncNativeFocusedLaunch();
                            },
                    ),
                  if (_pendingRemoveId != null)
                    _RemoveConfirm(
                      name:
                          _library.byId(_pendingRemoveId!)?.displayName ??
                          'this app',
                      scale: metrics.scale,
                      onConfirm: () {
                        final id = _pendingRemoveId!;
                        setState(() => _pendingRemoveId = null);
                        _library.remove(id);
                        unawaited(_clearRemoveArmedAndSyncLaunch());
                      },
                      onCancel: () {
                        setState(() => _pendingRemoveId = null);
                        unawaited(_clearRemoveArmedAndSyncLaunch());
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabBody(HomeDeckMetrics metrics, int page, int pages) {
    switch (_tab) {
      case HomeTab.games:
        return PlaceholderTab(title: 'Games', metrics: metrics);
      case HomeTab.achievements:
        return PlaceholderTab(title: 'Achievements', metrics: metrics);
      case HomeTab.friends:
        return PlaceholderTab(title: 'Friends', metrics: metrics);
      case HomeTab.allApps:
        return LibraryView(
          controller: _library,
          metrics: metrics,
          mode: _libraryMode,
          focusedId: _focusedId,
          hoveredId: _hoveredId,
          chipsFocused: _chipsFocused,
          openFolderTitle: _folderTitle,
          onOpenFolder: _openFolder,
          onCloseFolder: _closeFolder,
          onFocus: (id) {
            if (_insideFolder && isFolderFocusId(id)) {
              return;
            }
            if (_focusedId != id) {
              _click(UiClick.move);
              setState(() {
                _focusedId = id;
                _chipsFocused = false;
              });
            }
          },
          onHover: (id) => setState(() => _hoveredId = id),
          onLaunch: _launch,
          onAdd: _addApp,
          onMode: (mode) => setState(() => _libraryMode = mode),
          focusNodeFor: _nodeFor,
        );
      case HomeTab.home:
        final slots = _library.homeSlots(
          minLength: HomePager.slotCount(pages, metrics),
        );
        return Column(
          children: [
            if (_moveMode)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Move mode  ·  D-pad  ·  A to drop',
                  key: const Key('move-mode-hint'),
                  style: TextStyle(
                    color: HomeDeckColors.cyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 13 * metrics.scale,
                  ),
                ),
              ),
            Expanded(
              child: HomePagedView(
                controller: _library,
                metrics: metrics,
                slots: slots,
                page: page,
                pages: pages,
                focusedId: _focusedId,
                hoveredId: _hoveredId,
                moveMode: _moveMode,
                music: widget.music,
                onFocus: (id) {
                  if (_focusedId != id) {
                    _focusId(id);
                  }
                },
                onHover: (id) => setState(() => _hoveredId = id),
                onLaunch: _launch,
                onEmptyActivate: (_) => _addApp(),
                onReorderDrop: _onReorderDrop,
                onPage: _goToPage,
                focusNodeFor: _nodeFor,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SubtlePageDots(
                count: pages,
                page: page,
                onSelect: _goToPage,
              ),
            ),
          ],
        );
    }
  }
}

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.name,
    required this.scale,
    required this.onClose,
    this.kindLabel,
    this.path,
    this.romPath,
    this.onAddToHome,
    this.onRemoveFromHome,
    this.onRemove,
  });

  final String name;
  final String? kindLabel;
  final String? path;
  final String? romPath;
  final double scale;
  final VoidCallback onClose;
  final VoidCallback? onAddToHome;
  final VoidCallback? onRemoveFromHome;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1B2433),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: HomeDeckColors.cyan, width: 2),
            ),
            child: Padding(
              padding: EdgeInsets.all(28 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    key: const Key('details-title'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24 * scale,
                    ),
                  ),
                  if (kindLabel != null) ...[
                    SizedBox(height: 8 * scale),
                    Text(
                      kindLabel!,
                      key: const Key('details-kind'),
                      style: TextStyle(
                        color: HomeDeckColors.cyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 14 * scale,
                      ),
                    ),
                  ],
                  if (path != null) ...[
                    SizedBox(height: 10 * scale),
                    Text(
                      path!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HomeDeckColors.muted,
                        fontSize: 13 * scale,
                      ),
                    ),
                  ],
                  if (romPath != null) ...[
                    SizedBox(height: 6 * scale),
                    Text(
                      romPath!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HomeDeckColors.muted,
                        fontSize: 13 * scale,
                      ),
                    ),
                  ],
                  SizedBox(height: 22 * scale),
                  if (onAddToHome != null)
                    TextButton(
                      key: const Key('details-add-to-home'),
                      onPressed: onAddToHome,
                      child: const Text('Add to Home'),
                    ),
                  if (onRemoveFromHome != null)
                    TextButton(
                      key: const Key('details-remove-from-home'),
                      onPressed: onRemoveFromHome,
                      child: const Text('Remove from Home'),
                    ),
                  SizedBox(height: 8 * scale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: onClose,
                        child: const Text('Close  ·  B'),
                      ),
                      if (onRemove != null) ...[
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: onRemove,
                          style: FilledButton.styleFrom(
                            backgroundColor: HomeDeckColors.danger,
                          ),
                          child: const Text('Remove'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveConfirm extends StatelessWidget {
  const _RemoveConfirm({
    required this.name,
    required this.scale,
    required this.onConfirm,
    required this.onCancel,
  });

  final String name;
  final double scale;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('remove-confirm'),
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF1B2433),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: HomeDeckColors.cyan, width: 3),
            ),
            child: Padding(
              padding: EdgeInsets.all(28 * scale),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Remove from library?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24 * scale,
                    ),
                  ),
                  SizedBox(height: 10 * scale),
                  Text(
                    name,
                    style: TextStyle(
                      color: HomeDeckColors.cyan,
                      fontWeight: FontWeight.w700,
                      fontSize: 20 * scale,
                    ),
                  ),
                  SizedBox(height: 22 * scale),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        key: const Key('remove-confirm-cancel'),
                        onPressed: onCancel,
                        child: const Text(
                          'Cancel  ·  B',
                          style: TextStyle(
                            color: HomeDeckColors.muted,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        key: const Key('remove-confirm-ok'),
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeDeckColors.danger,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Remove  ·  A'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
