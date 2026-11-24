import 'package:flutter/widgets.dart';

/// Fullscreen / borderless chrome. UI talks to this, never to window_manager.
abstract class WindowModeController extends ChangeNotifier {
  bool get isFullscreen;
  bool get isBorderless;

  Future<void> apply(bool fullscreen, bool borderless);

  Future<void> toggleFullscreen();

  Future<void> toggleBorderless();

  Future<void> prepareInitialFrame() async {}
}

class MemoryWindowModeController extends WindowModeController {
  MemoryWindowModeController({bool fullscreen = false, bool borderless = false})
    : _fullscreen = fullscreen,
      _borderless = borderless;

  bool _fullscreen;
  bool _borderless;

  @override
  bool get isFullscreen => _fullscreen;

  @override
  bool get isBorderless => _borderless;

  @override
  Future<void> apply(bool fullscreen, bool borderless) async {
    _fullscreen = fullscreen;
    _borderless = borderless;
    notifyListeners();
  }

  @override
  Future<void> toggleFullscreen() => apply(!_fullscreen, _borderless);

  @override
  Future<void> toggleBorderless() => apply(_fullscreen, !_borderless);
}
