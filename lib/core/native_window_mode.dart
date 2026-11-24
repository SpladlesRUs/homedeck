import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/platform/windows_native_bridge.dart';
import 'package:homedeck/platform/windows_window_chrome.dart';
import 'package:window_manager/window_manager.dart';

/// Production controller backed by the Windows runner MethodChannel first,
/// then Dart FFI FindWindow, then window_manager 0.7.
///
/// Ally re-smoke at 2417533 measured caption True / 1280×720 /
/// chromeChanged=False because window_manager never bound the HWND and
/// FindWindow from Dart did not land. The runner channel uses the real
/// Create() HWND; native WM_KEYDOWN F11 also toggles and pushes state here.
class NativeWindowModeController extends WindowModeController {
  NativeWindowModeController() {
    if (Platform.isWindows) {
      _nativeFullscreenSub =
          WindowsNativeBridge.fullscreenChanges.listen(_onNativeFullscreen);
    }
  }

  static const _defaultSize = Size(1280, 800);

  bool _fullscreen = false;
  bool _borderless = false;
  Size? _restoreSize;
  Offset? _restorePosition;
  ListenerId? _eventListener;
  StreamSubscription<bool>? _nativeFullscreenSub;
  DateTime? _lastNativeFullscreenAt;
  final _focusListeners = <ValueChanged<bool>>[];

  /// Prefer the current window; on Windows getCurrent() can be null until the
  /// Flutter view is attached, so fall back to the first known window.
  Window? get _window {
    final current = WindowManager.instance.getCurrent();
    if (current != null) {
      return current;
    }
    final all = WindowManager.instance.getAll();
    if (all.isEmpty) {
      return null;
    }
    return all.first;
  }

  @override
  // Trust the local flag: on some Windows handhelds `window.isFullScreen`
  // stays false even after a successful chrome/size change.
  bool get isFullscreen => _fullscreen;

  @override
  bool get isBorderless => _borderless;

  @override
  Future<void> prepareInitialFrame() async {
    final window = await _waitForWindow();
    if (window != null) {
      window.title = 'HomeDeck';
      window.setSize(_defaultSize.toNative(), false);
      window.minimumSize = const Size(960, 600).toNative();
      window.center();
      _eventListener ??= window.addListener((event) {
        if (event is WindowFocusedEvent) {
          _emitFocus(true);
        } else if (event is WindowBlurredEvent) {
          _emitFocus(false);
        }
      });
    }
    // Even when window_manager never binds the HWND, set the title via the
    // runner Create() string (already "HomeDeck") and leave size to main.cpp
    // (1280×800). Native chrome path uses the Create() HWND directly.
  }

  Future<Window?> _waitForWindow() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final window = _window;
      if (window != null) {
        return window;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return _window;
  }

  void _onNativeFullscreen(bool fullscreen) {
    _lastNativeFullscreenAt = DateTime.now();
    if (_fullscreen == fullscreen) {
      notifyListeners();
      return;
    }
    _fullscreen = fullscreen;
    notifyListeners();
  }

  @override
  Future<void> apply(bool fullscreen, bool borderless) async {
    _fullscreen = fullscreen;
    _borderless = borderless;

    var applied = false;
    if (Platform.isWindows) {
      // 1) Runner MethodChannel — real HWND from FlutterWindow.
      applied = await WindowsNativeBridge.setFullscreen(fullscreen);
      // 2) Dart FFI FindWindow fallback (tests / older builds).
      if (!applied) {
        applied = WindowsWindowChrome.apply(
          fullscreen: fullscreen,
          borderless: borderless,
        );
      }
    }

    final window = await _waitForWindow();
    if (window != null && !applied) {
      if (fullscreen) {
        _restoreSize ??= window.size.toSize();
        _restorePosition ??= window.position.toOffset();
        window.isFullScreen = true;
        window.setFrameless(true);
        window.maximize();
      } else {
        window.isFullScreen = false;
        if (window.isMaximized) {
          window.unmaximize();
        }
        if (borderless) {
          window.setFrameless(true);
        } else {
          window.setFrameless(false);
          window.titleBarStyle = TitleBarStyle.normal;
        }
        final size = _restoreSize ?? _defaultSize;
        window.setSize(size.toNative(), false);
        final origin = _restorePosition;
        if (origin != null) {
          window.position = origin.toNative();
        } else {
          window.center();
        }
      }
    } else if (window != null && applied && !fullscreen) {
      // Keep window_manager state loosely in sync after Win32 restore.
      window.isFullScreen = false;
      window.setFrameless(borderless);
      if (!borderless) {
        window.titleBarStyle = TitleBarStyle.normal;
      }
    }

    notifyListeners();
  }

  @override
  Future<void> toggleFullscreen() async {
    // Native WM_KEYDOWN F11 may already have applied chrome for this key.
    // Skip a second Dart toggle so Ally does not see chromeChanged flicker
    // back to the captioned 1280×720 window.
    final last = _lastNativeFullscreenAt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(milliseconds: 400)) {
      notifyListeners();
      return;
    }
    await apply(!_fullscreen, _borderless);
  }

  @override
  Future<void> toggleBorderless() => apply(_fullscreen, !_borderless);

  @override
  Future<void> close() async {
    await _nativeFullscreenSub?.cancel();
    _nativeFullscreenSub = null;
    _window?.close();
  }

  @override
  void addFocusListener(ValueChanged<bool> listener) {
    _focusListeners.add(listener);
  }

  @override
  void removeFocusListener(ValueChanged<bool> listener) {
    _focusListeners.remove(listener);
  }

  void _emitFocus(bool focused) {
    for (final listener in List<ValueChanged<bool>>.from(_focusListeners)) {
      listener(focused);
    }
  }
}
