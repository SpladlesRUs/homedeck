import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Method channel to the Windows runner (`homedeck/win32`).
///
/// Ally Phase2 at 4996779 still failed Enter/F11 because the harness uses
/// `WScript.Shell.SendKeys` after AppActivate — keys hit the Flutter view
/// child, not `FlutterWindow::MessageHandler`. The runner now installs a
/// WH_KEYBOARD_LL hook for F11/Enter while HomeDeck is foreground, and Dart
/// mirrors the focused launch path via [setFocusedLaunch].
///
/// Ally @9800850: F11 PASS via the hook, but Enter still spawned no process
/// because `focused_path_` was often empty (cleared during Add-sheet library
/// notify / async mirror race). The hook now falls back to invoking
/// [onLaunchFocused] in Dart when the mirrored path is missing.
class WindowsNativeBridge {
  WindowsNativeBridge._();

  static const MethodChannel _channel = MethodChannel('homedeck/win32');

  static final StreamController<bool> _fullscreenChanges =
      StreamController<bool>.broadcast();

  static bool _listening = false;

  /// Runner asks Dart to launch the focused tile when the mirrored path is
  /// empty (Enter via WH_KEYBOARD_LL / top-level WM_KEYDOWN).
  static Future<void> Function()? onLaunchFocused;

  /// Ensure the platform method handler is registered (launchFocused +
  /// fullscreenChanged). Call from HomeScreen init on Windows.
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
}
