/// Buttons HomeDeck actually handles. Mapped from XInput and from keyboard.
enum GamepadButton {
  a,
  b,
  x,
  y,
  lb,
  rb,
  lt,
  rt,
  start,
  back,
  dpadUp,
  dpadDown,
  dpadLeft,
  dpadRight,
}

typedef GamepadHandler = void Function(GamepadButton button);

/// OS-agnostic gamepad. Widgets talk to this, never to XInput.
abstract class GamepadSource {
  bool get isConnected;

  void start(GamepadHandler onButton);

  void stop();
}

/// Tests and non-Windows hosts. Call [emit] to simulate a press.
class MemoryGamepadSource implements GamepadSource {
  GamepadHandler? _handler;
  bool connected;

  MemoryGamepadSource({this.connected = false});

  @override
  bool get isConnected => connected;

  @override
  void start(GamepadHandler onButton) {
    _handler = onButton;
  }

  @override
  void stop() {
    _handler = null;
  }

  void emit(GamepadButton button) {
    connected = true;
    _handler?.call(button);
  }
}

class IdleGamepadSource implements GamepadSource {
  @override
  bool get isConnected => false;

  @override
  void start(GamepadHandler onButton) {}

  @override
  void stop() {}
}
