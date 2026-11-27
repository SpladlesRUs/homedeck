import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Method channel to the Windows runner (`homedeck/win32`).
///
/// Ally Phase2 SendKeys land on the Flutter view child — Shortcuts often
/// never see `a`, so MethodChannel `pickOpenFile` never ran and the harness
/// logged "Open dialog not found". The runner WH_KEYBOARD_LL hook posts
/// `WM_HOMEDECK_ADD`, shows classic `GetOpenFileName` titled **Open**
/// (class `#32770`), then invokes [onAddPickedPath]. Bare `s` posts
/// `WM_HOMEDECK_SCAN_STEAM` → [onScanSteam] (Steam discover without Settings
/// UIA). Bare `p` posts `WM_HOMEDECK_SCAN_START_MENU` → [onScanStartMenu]
/// (Start Menu Programs discover without Settings UIA). Bare `r` posts
/// `WM_HOMEDECK_SCAN_ROMS` → [onScanRoms] (ROM-folder discover without
/// Settings UIA). Bare `e` posts `WM_HOMEDECK_SCAN_EPIC` → [onScanEpic]
/// (Epic Games discover without Settings UIA). Bare `g` posts
/// `WM_HOMEDECK_SCAN_GOG` → [onScanGog] (GOG Galaxy discover without
/// Settings UIA). Bare `u` posts `WM_HOMEDECK_SCAN_UBISOFT` → [onScanUbisoft]
/// (Ubisoft Connect discover without Settings UIA). Bare `o` posts
/// `WM_HOMEDECK_SCAN_EA` → [onScanEa] (EA App / Origin discover without
/// Settings UIA). Bare `n` posts `WM_HOMEDECK_SCAN_BATTLENET` →
/// [onScanBattlenet] (Battle.net discover without Settings UIA). Bare `w`
/// posts `WM_HOMEDECK_SCAN_XBOX` → [onScanXbox] (Xbox / Microsoft Store
/// discover without Settings UIA). Bare `h` posts `WM_HOMEDECK_PIN_HOME` →
/// [onPinFocusedToHome] (same as UI Add to Home — no UIA on the menu). Bare
/// Delete/Backspace posts `WM_HOMEDECK_REMOVE` → [onRemoveFocused] (same as
/// RemoveFocusedIntent). While Library remove is pending, Enter posts
/// `WM_HOMEDECK_CONFIRM` → [onConfirmFocused] (not ShellExecute). Bare
/// VK_OEM_PLUS / VK_ADD posts `WM_HOMEDECK_OPEN_MENU` → [onOpenMenu] (same
/// as OpenMenuIntent — idle-hide drops Shortcuts focus so Ally SendKeys
/// `=` never opened the menu). Bare VK_OEM_MINUS posts
/// `WM_HOMEDECK_OPEN_DETAILS` → [onOpenDetails] (same as OpenDetailsIntent
/// — idle-hide drops Shortcuts focus so Ally SendKeys `-` never opened
/// Details). Bare `y` posts `WM_HOMEDECK_OPEN_SEARCH` → [onOpenSearch]
/// (same as OpenSearchIntent — idle-hide drops Shortcuts focus so Ally
/// SendKeys `y` never opened Global Search). Bare `t` posts
/// `WM_HOMEDECK_OPEN_NOTIFICATIONS` → [onOpenNotifications] (same as
/// OpenNotificationsIntent — idle-hide drops Shortcuts focus so Ally
/// SendKeys `t` never opened Notifications). Bare `f` posts
/// `WM_HOMEDECK_OPEN_FRIENDS` → [onOpenFriends] (same as
/// OpenFriendsIntent — idle-hide drops Shortcuts focus so Ally
/// SendKeys `f` never opened Friends). The same hook handles F11
/// chrome and Enter→focused path; Dart mirrors the target via
/// [setFocusedLaunch] and handles a native [onLaunchFocused] fallback when
/// the mirrored path is empty.
class WindowsNativeBridge {
  WindowsNativeBridge._();

  static const MethodChannel _channel = MethodChannel('homedeck/win32');

  static final StreamController<bool> _fullscreenChanges =
      StreamController<bool>.broadcast();

  static bool _listening = false;

  /// Runner asks Dart to launch the focused tile when the mirrored path is
  /// empty (Enter via WH_KEYBOARD_LL / top-level WM_KEYDOWN).
  static Future<void> Function()? onLaunchFocused;

  /// Runner finished a native Open pick (WH_KEYBOARD_LL `A` / WM_HOMEDECK_ADD)
  /// and wants Dart to persist + write `icons/<id>.png`.
  static Future<void> Function(String path)? onAddPickedPath;

  /// Runner WH_KEYBOARD_LL bare `S` / `WM_HOMEDECK_SCAN_STEAM` asks Dart to
  /// run Steam `discover()` → `importDiscovered` (same as Settings scan).
  static Future<void> Function()? onScanSteam;

  /// Runner WH_KEYBOARD_LL bare `P` / `WM_HOMEDECK_SCAN_START_MENU` asks Dart
  /// to run Start Menu Programs `discover()` → `importDiscovered`.
  static Future<void> Function()? onScanStartMenu;

  /// Runner WH_KEYBOARD_LL bare `R` / `WM_HOMEDECK_SCAN_ROMS` asks Dart to
  /// run ROM-folder `discover()` → `importRoms`.
  static Future<void> Function()? onScanRoms;

  /// Runner WH_KEYBOARD_LL bare `E` / `WM_HOMEDECK_SCAN_EPIC` asks Dart to
  /// run Epic Games `discoverEpic()` → `importEpic`.
  static Future<void> Function()? onScanEpic;

  /// Runner WH_KEYBOARD_LL bare `G` / `WM_HOMEDECK_SCAN_GOG` asks Dart to
  /// run GOG Galaxy `discoverGog()` → `importGog`.
  static Future<void> Function()? onScanGog;

  /// Runner WH_KEYBOARD_LL bare `U` / `WM_HOMEDECK_SCAN_UBISOFT` asks Dart to
  /// run Ubisoft Connect `discoverUbisoft()` → `importUbisoft`.
  static Future<void> Function()? onScanUbisoft;

  /// Runner WH_KEYBOARD_LL bare `O` / `WM_HOMEDECK_SCAN_EA` asks Dart to
  /// run EA App / Origin `discoverEa()` → `importEa`.
  static Future<void> Function()? onScanEa;

  /// Runner WH_KEYBOARD_LL bare `N` / `WM_HOMEDECK_SCAN_BATTLENET` asks Dart
  /// to run Battle.net `discoverBattlenet()` → `importBattlenet`.
  static Future<void> Function()? onScanBattlenet;

  /// Runner WH_KEYBOARD_LL bare `W` / `WM_HOMEDECK_SCAN_XBOX` asks Dart to
  /// run Xbox / Microsoft Store `discoverXbox()` → `importXbox`.
  static Future<void> Function()? onScanXbox;

  /// Runner WH_KEYBOARD_LL bare `H` / `WM_HOMEDECK_PIN_HOME` asks Dart to pin
  /// the focused Library record onto Home (same as UI Add to Home).
  static Future<void> Function()? onPinFocusedToHome;

  /// Runner WH_KEYBOARD_LL bare Delete/Backspace / `WM_HOMEDECK_REMOVE` asks
  /// Dart to unpin (Home) or show Library remove confirm (`_requestRemove`).
  static Future<void> Function()? onRemoveFocused;

  /// Runner WH_KEYBOARD_LL bare VK_OEM_PLUS / VK_ADD / `WM_HOMEDECK_OPEN_MENU`
  /// asks Dart to open the TileMenu (same as OpenMenuIntent).
  static Future<void> Function()? onOpenMenu;

  /// Runner WH_KEYBOARD_LL bare VK_OEM_MINUS / `WM_HOMEDECK_OPEN_DETAILS`
  /// asks Dart to open the Details menu (same as OpenDetailsIntent).
  static Future<void> Function()? onOpenDetails;

  /// Runner WH_KEYBOARD_LL bare `Y` / `WM_HOMEDECK_OPEN_SEARCH` asks Dart
  /// to open Global Search (same as OpenSearchIntent / `_openSearch`).
  static Future<void> Function()? onOpenSearch;

  /// Runner WH_KEYBOARD_LL bare `T` / `WM_HOMEDECK_OPEN_NOTIFICATIONS` asks
  /// Dart to open Notifications (same as OpenNotificationsIntent /
  /// `_openNotifications`).
  static Future<void> Function()? onOpenNotifications;

  /// Runner WH_KEYBOARD_LL bare `F` / `WM_HOMEDECK_OPEN_FRIENDS` asks Dart
  /// to open Friends (same as OpenFriendsIntent / `_openFriends`).
  static Future<void> Function()? onOpenFriends;

  /// Runner WH_KEYBOARD_LL Enter while remove-armed / `WM_HOMEDECK_CONFIRM`
  /// asks Dart `_handleConfirm` (Library remove) without ShellExecute.
  static Future<void> Function()? onConfirmFocused;

  /// Runner finished waiting on a tracked local launch process and restored
  /// HomeDeck (when Settings restore-on-exit is ON). Dart unducks music and
  /// persists window prefs; chrome/foreground already applied natively.
  static Future<void> Function()? onGameExited;

  /// Ensure the platform method handler is registered. Call from HomeScreen
  /// init on Windows.
  static void ensureInitialized() => _ensureListening();

  /// Absolute fullscreen notifications from the runner (native F11 path).
  static Stream<bool> get fullscreenChanges {
    _ensureListening();
    return _fullscreenChanges.stream;
  }

  static void _ensureListening() {
    if (_listening || !Platform.isWindows) {
      return;
    }
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fullscreenChanged') {
        final value = call.arguments;
        if (value is bool) {
          _fullscreenChanges.add(value);
        }
        return;
      }
      if (call.method == 'launchFocused') {
        final handler = onLaunchFocused;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'addPickedPath') {
        final raw = call.arguments;
        final path = raw is String ? raw.trim() : '';
        if (path.isEmpty) {
          return;
        }
        final handler = onAddPickedPath;
        if (handler != null) {
          await handler(path);
        }
        return;
      }
      if (call.method == 'scanSteam') {
        final handler = onScanSteam;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'scanStartMenu') {
        final handler = onScanStartMenu;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'scanRoms') {
        final handler = onScanRoms;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'scanEpic') {
        final handler = onScanEpic;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'scanGog') {
        final handler = onScanGog;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'scanUbisoft') {
        final handler = onScanUbisoft;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'scanEa') {
        final handler = onScanEa;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'scanBattlenet') {
        final handler = onScanBattlenet;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'scanXbox') {
        final handler = onScanXbox;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'pinFocusedToHome') {
        final handler = onPinFocusedToHome;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'removeFocused') {
        final handler = onRemoveFocused;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'openMenu') {
        final handler = onOpenMenu;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'openDetails') {
        final handler = onOpenDetails;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'openSearch') {
        final handler = onOpenSearch;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'openNotifications') {
        final handler = onOpenNotifications;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'openFriends') {
        final handler = onOpenFriends;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'confirmFocused') {
        final handler = onConfirmFocused;
        if (handler != null) {
          await handler();
        }
        return;
      }
      if (call.method == 'gameExited') {
        final handler = onGameExited;
        if (handler != null) {
          await handler();
        }
        return;
      }
    });
  }

  /// Resolve a `.lnk` via IShellLink GetPath / GetArguments.
  ///
  /// Returns a map with optional `target` (String) and `arguments` (String
  /// command line), or null when unavailable. UWP / URL-only shortcuts often
  /// have an empty GetPath — callers should keep the `.lnk` itself.
  static Future<Map<String, Object?>?> resolveShortcut(String lnkPath) async {
    if (!Platform.isWindows) {
      return null;
    }
    final trimmed = lnkPath.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'resolveShortcut',
        <String, Object?>{'path': trimmed},
      );
      if (result is! Map) {
        return null;
      }
      return Map<String, Object?>.from(result);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Ask the runner to apply frameless monitor-cover chrome.
  /// Returns false when the plugin is missing (tests / non-Windows).
  static Future<bool> setFullscreen(bool fullscreen) async {
    if (!Platform.isWindows) {
      return false;
    }
    _ensureListening();
    try {
      final result = await _channel.invokeMethod<bool>(
        'setFullscreen',
        <String, Object?>{'fullscreen': fullscreen},
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// ShellExecuteW via the runner. Returns false when unavailable / failed.
  static Future<bool> launch(
    String path, {
    List<String> arguments = const [],
  }) async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>(
        'launch',
        <String, Object?>{
          'path': path,
          'arguments': arguments,
        },
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Tell the runner which path Enter should ShellExecute (keyboard hook).
  static Future<void> setFocusedLaunch(
    String? path, {
    List<String> arguments = const [],
  }) async {
    if (!Platform.isWindows) {
      return;
    }
    _ensureListening();
    try {
      await _channel.invokeMethod<void>(
        'setFocusedLaunch',
        <String, Object?>{
          'path': path ?? '',
          'arguments': arguments,
        },
      );
    } on MissingPluginException {
      // Tests / non-runner.
    } on PlatformException {
      // Ignore — Dart Enter path remains.
    }
  }

  /// Ally Delete→Enter: while [armed], Enter confirms Library remove instead
  /// of ShellExecute. Cleared after Home unpin or confirm/cancel.
  static Future<void> setRemoveArmed(bool armed) async {
    if (!Platform.isWindows) {
      return;
    }
    _ensureListening();
    try {
      await _channel.invokeMethod<void>(
        'setRemoveArmed',
        <String, Object?>{'armed': armed},
      );
    } on MissingPluginException {
      // Tests / non-runner.
    } on PlatformException {
      // Ignore — Dart Shortcuts path remains.
    }
  }

  /// Mirror Settings “Fullscreen on launch” so Ally Enter (native ShellExecute
  /// without a Dart round-trip) can enter the same F11 chrome after launch.
  static Future<void> setFullscreenOnLaunch(bool enabled) async {
    if (!Platform.isWindows) {
      return;
    }
    _ensureListening();
    try {
      await _channel.invokeMethod<void>(
        'setFullscreenOnLaunch',
        <String, Object?>{'enabled': enabled},
      );
    } on MissingPluginException {
      // Tests / non-runner.
    } on PlatformException {
      // Ignore — Dart launch path still honors the pref.
    }
  }

  /// Mirror Settings “Return to HomeDeck when game exits” so Ally Enter
  /// (native ShellExecute without a Dart round-trip) restores on process exit.
  static Future<void> setRestoreOnExit(bool enabled) async {
    if (!Platform.isWindows) {
      return;
    }
    _ensureListening();
    try {
      await _channel.invokeMethod<void>(
        'setRestoreOnExit',
        <String, Object?>{'enabled': enabled},
      );
    } on MissingPluginException {
      // Tests / non-runner.
    } on PlatformException {
      // Ignore — native default stays ON until mirrored.
    }
  }

  /// Extract a PE / `.lnk` icon as PNG bytes via the runner (WIC).
  /// Returns null when unavailable, missing plugin, or extraction fails.
  static Future<Uint8List?> extractIconPng(
    String path, {
    int size = 256,
  }) async {
    if (!Platform.isWindows) {
      return null;
    }
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<dynamic>(
        'extractIcon',
        <String, Object?>{'path': trimmed, 'size': size},
      );
      if (result is Uint8List && result.isNotEmpty) {
        return result;
      }
      if (result is List<int> && result.isNotEmpty) {
        return Uint8List.fromList(result);
      }
      return null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Classic GetOpenFileName titled `Open` (Ally FindWindow / SendKeys).
  ///
  /// Returns the selected path, `null` when cancelled. Optional
  /// `HOMEDECK_ADD_PATH` env bypasses the modal with a fixed path.
  /// Throws [MissingPluginException] when the runner channel is absent.
  static Future<String?> pickOpenFile({
    required String label,
    required List<String> extensions,
    String confirmButtonText = 'Add to HomeDeck',
  }) async {
    if (!Platform.isWindows) {
      return null;
    }
    _ensureListening();
    final result = await _channel.invokeMethod<String>(
      'pickOpenFile',
      <String, Object?>{
        'label': label,
        'extensions': extensions,
        'confirmButtonText': confirmButtonText,
      },
    );
    if (result == null || result.trim().isEmpty) {
      return null;
    }
    return result;
  }

  /// Write [bytes] to an absolute [path] via Win32 CreateFile + FlushFileBuffers.
  /// Used as a dual-write for IconCache so Ally sees PNGs under AppData.
  static Future<bool> writeFile(String path, Uint8List bytes) async {
    if (!Platform.isWindows) {
      return false;
    }
    final trimmed = path.trim();
    if (trimmed.isEmpty || bytes.isEmpty) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>(
        'writeFile',
        <String, Object?>{
          'path': trimmed,
          'bytes': bytes,
        },
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
