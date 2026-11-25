import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Method channel to the Windows runner (`homedeck/win32`).
///
/// Ally Phase2 at 2417533 still failed Enter/F11 when Dart FFI used
/// ShellExecuteW + FindWindow — the runner never changed chrome and notepad
/// never spawned. M2 at 8715ce4 left `icons\` empty with Dart FFI extract.
/// The C++ side owns HWND, ShellExecute, and PE/.lnk → PNG extraction.
class WindowsNativeBridge {
  WindowsNativeBridge._();

  static const MethodChannel _channel = MethodChannel('homedeck/win32');

  static final StreamController<bool> _fullscreenChanges =
      StreamController<bool>.broadcast();

  static bool _listening = false;

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
