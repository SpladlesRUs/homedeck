import 'package:flutter/widgets.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:window_manager/window_manager.dart';

/// Production controller backed by window_manager 0.7's native Window API.
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
    if (window == null) {
      return;
    }
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
    final window = await _waitForWindow();
    if (window == null) {
      notifyListeners();
      return;
    }
    if (fullscreen) {
      _restoreSize ??= window.size.toSize();
      _restorePosition ??= window.position.toOffset();
      // Ally smoke at 27ba8ec: F11 left 1280×720 with chromeChanged=false when
      // only `isFullScreen` was toggled. Drive a visible change: native
      // fullscreen + frameless + cover the primary display.
      window.isFullScreen = true;
      window.setFrameless(true);
      final display = DisplayManager.instance.getPrimary();
      if (display != null) {
        window.position = display.position;
        window.setSize(display.size, false);
      } else {
        window.maximize();
      }
    } else {
      window.isFullScreen = false;
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
