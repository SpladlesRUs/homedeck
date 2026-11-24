import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:homedeck/platform/windows_window_chrome.dart';
import 'package:window_manager/window_manager.dart';

/// Production controller backed by window_manager 0.7's native Window API,
/// with a Win32 HWND fallback on Windows (Ally F11 chromeChanged=false).
class NativeWindowModeController extends WindowModeController {
  NativeWindowModeController();

  static const _defaultSize = Size(1280, 800);

  bool _fullscreen = false;
  bool _borderless = false;
  Size? _restoreSize;
  Offset? _restorePosition;
  ListenerId? _eventListener;
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
    // (1280×800). Win32 chrome path uses FindWindow by that title.
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

  @override
  Future<void> apply(bool fullscreen, bool borderless) async {
    _fullscreen = fullscreen;
    _borderless = borderless;

    // Windows: drive the real runner HWND first. Ally re-smoke at 80e8517
    // measured caption True / style 0x14CF0000 / chromeChanged=False because
    // window_manager never found the Flutter runner window.
    var win32Applied = false;
    if (Platform.isWindows) {
      win32Applied = WindowsWindowChrome.apply(
        fullscreen: fullscreen,
        borderless: borderless,
      );
    }

    final window = await _waitForWindow();
    if (window != null && !win32Applied) {
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
    } else if (window != null && win32Applied && !fullscreen) {
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
  Future<void> toggleFullscreen() => apply(!_fullscreen, _borderless);

  @override
  Future<void> toggleBorderless() => apply(_fullscreen, !_borderless);

  @override
  Future<void> close() async {
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
