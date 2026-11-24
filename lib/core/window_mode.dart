import 'package:flutter/widgets.dart';

/// Fullscreen / borderless chrome. UI talks to this, never to window_manager.
abstract class WindowModeController extends ChangeNotifier {
  bool get isFullscreen;
  bool get isBorderless;

  Future<void> apply(bool fullscreen, bool borderless);

  Future<void> toggleFullscreen();

  Future<void> toggleBorderless();

  Future<void> prepareInitialFrame() async {}

  Future<void> close() async {}

  /// True when the HomeDeck window gains native focus, false on blur.
  void addFocusListener(ValueChanged<bool> listener) {}

  void removeFocusListener(ValueChanged<bool> listener) {}
}

class MemoryWindowModeController extends WindowModeController {
  MemoryWindowModeController({bool fullscreen = false, bool borderless = false})
    : _fullscreen = fullscreen,
      _borderless = borderless;

  bool _fullscreen;
  bool _borderless;
  bool closed = false;
  final _focusListeners = <ValueChanged<bool>>[];

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

  @override
  Future<void> close() async {
    closed = true;
    notifyListeners();
  }

  @override
  void addFocusListener(ValueChanged<bool> listener) {
    _focusListeners.add(listener);
  }

  @override
  void removeFocusListener(ValueChanged<bool> listener) {
    _focusListeners.remove(listener);
  }

  /// Tests simulate alt-tab / game foregrounding.
  void emitFocus(bool focused) {
    for (final listener in List<ValueChanged<bool>>.from(_focusListeners)) {
      listener(focused);
    }
  }
}
