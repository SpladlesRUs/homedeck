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
/// UIA). The same hook handles F11 chrome and Enter→focused path; Dart
/// mirrors the target via [setFocusedLaunch] and handles a native
/// [onLaunchFocused] fallback when the mirrored path is empty.
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
    });
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
