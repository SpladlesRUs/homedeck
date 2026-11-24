import 'package:flutter/widgets.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:window_manager/window_manager.dart';

/// Production controller backed by window_manager 0.7's native Window API.
class NativeWindowModeController extends WindowModeController {
  NativeWindowModeController();

  bool _fullscreen = false;
  bool _borderless = false;
  ListenerId? _eventListener;
  final _focusListeners = <ValueChanged<bool>>[];

  Window? get _window => WindowManager.instance.getCurrent();

  @override
  bool get isFullscreen => _window?.isFullScreen ?? _fullscreen;

  @override
  bool get isBorderless => _borderless;

  @override
  Future<void> prepareInitialFrame() async {
    final window = _window;
    if (window == null) {
      return;
    }
    window.title = 'HomeDeck';
    window.setSize(const Size(1280, 800).toNative(), false);
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

  @override
  Future<void> apply(bool fullscreen, bool borderless) async {
    _fullscreen = fullscreen;
    _borderless = borderless;
    final window = _window;
    if (window != null) {
      window.isFullScreen = fullscreen;
      if (borderless) {
        window.setFrameless(true);
      } else {
        window.setFrameless(false);
        window.titleBarStyle = TitleBarStyle.normal;
      }
    }
    notifyListeners();
  }

  @override
  Future<void> toggleFullscreen() => apply(!isFullscreen, _borderless);

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
