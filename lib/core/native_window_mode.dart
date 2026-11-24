import 'package:flutter/widgets.dart';
import 'package:homedeck/core/window_mode.dart';
import 'package:window_manager/window_manager.dart';

/// Production controller backed by window_manager 0.7's native Window API.
class NativeWindowModeController extends WindowModeController {
  NativeWindowModeController();

  bool _fullscreen = false;
  bool _borderless = false;

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
    window.setSize(const Size(1280, 720).toNative(), false);
    window.minimumSize = const Size(960, 540).toNative();
    window.center();
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
}
