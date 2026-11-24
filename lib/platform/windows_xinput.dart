// ignore_for_file: camel_case_types, non_constant_identifier_names, library_private_types_in_public_api

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:homedeck/core/gamepad.dart';

/// Polls XInput so D-pad / A / B / LB / RB work even when Flutter does not
/// deliver gamepad keys (common on Windows desktop and handhelds).
class WindowsXInputGamepad implements GamepadSource {
  WindowsXInputGamepad({this.pollInterval = const Duration(milliseconds: 16)});

  final Duration pollInterval;

  GamepadHandler? _handler;
  Timer? _timer;
  XInputGetStateDart? _getState;
  Pointer<XINPUT_STATE>? _state;
  int _prevButtons = 0;
  int _prevTriggers = 0;
  int _held = 0;
  DateTime? _repeatAt;
  bool _connected = false;
  bool _bindFailed = false;

  static const _up = 0x0001;
  static const _down = 0x0002;
  static const _left = 0x0004;
  static const _right = 0x0008;
  static const _start = 0x0010;
  static const _back = 0x0020;
  static const _lb = 0x0100;
  static const _rb = 0x0200;
  static const _a = 0x1000;
  static const _b = 0x2000;
  static const _x = 0x4000;
  static const _y = 0x8000;
  static const _deadzone = 20000;

  @override
  bool get isConnected => _connected;

  @override
  void start(GamepadHandler onButton) {
    _handler = onButton;
    if (!Platform.isWindows) {
      return;
    }
    _bind();
    _state ??= calloc<XINPUT_STATE>();
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _handler = null;
    final state = _state;
    if (state != null) {
      calloc.free(state);
      _state = null;
    }
  }

  void _bind() {
    if (_getState != null || _bindFailed) {
      return;
    }
    for (final name in ['xinput1_4.dll', 'xinput1_3.dll', 'xinput9_1_0.dll']) {
      try {
        final lib = DynamicLibrary.open(name);
        _getState = lib
            .lookup<NativeFunction<XInputGetStateNative>>('XInputGetState')
            .asFunction();
        return;
      } catch (_) {
        continue;
      }
    }
    _bindFailed = true;
  }

  void _poll() {
    final getState = _getState;
    final handler = _handler;
    final state = _state;
    if (getState == null || handler == null || state == null) {
      _connected = false;
      return;
    }
    try {
      var found = false;
      for (var i = 0; i < 4; i++) {
        if (getState(i, state) != 0) {
          continue;
        }
        found = true;
        var buttons = state.ref.Gamepad.wButtons;
        final pad = state.ref.Gamepad;
        if (pad.sThumbLY > _deadzone) {
          buttons |= _up;
        }
        if (pad.sThumbLY < -_deadzone) {
          buttons |= _down;
        }
        if (pad.sThumbLX < -_deadzone) {
          buttons |= _left;
        }
        if (pad.sThumbLX > _deadzone) {
          buttons |= _right;
        }
        final triggers = (pad.bLeftTrigger > 140 ? 1 : 0) |
            (pad.bRightTrigger > 140 ? 2 : 0);
        if (triggers & 1 != 0 && _prevTriggers & 1 == 0) {
          handler(GamepadButton.lt);
        }
        if (triggers & 2 != 0 && _prevTriggers & 2 == 0) {
          handler(GamepadButton.rt);
        }
        _prevTriggers = triggers;
        _dispatch(buttons, handler);
        break;
      }
      _connected = found;
      if (!found) {
        _prevButtons = 0;
        _prevTriggers = 0;
        _held = 0;
      }
    } catch (_) {
      // Never let a bad poll take down the launcher.
      _connected = false;
    }
  }

  void _dispatch(int buttons, GamepadHandler handler) {
    _press(buttons, _a, GamepadButton.a, handler);
    _press(buttons, _b, GamepadButton.b, handler);
    _press(buttons, _x, GamepadButton.x, handler);
    _press(buttons, _y, GamepadButton.y, handler);
    _press(buttons, _lb, GamepadButton.lb, handler);
    _press(buttons, _rb, GamepadButton.rb, handler);
    _press(buttons, _start, GamepadButton.start, handler);
    _press(buttons, _back, GamepadButton.back, handler);
    _repeatable(buttons, _up, GamepadButton.dpadUp, handler);
    _repeatable(buttons, _down, GamepadButton.dpadDown, handler);
    _repeatable(buttons, _left, GamepadButton.dpadLeft, handler);
    _repeatable(buttons, _right, GamepadButton.dpadRight, handler);
    _prevButtons = buttons;
  }

  void _press(int buttons, int mask, GamepadButton button, GamepadHandler handler) {
    if (buttons & mask != 0 && _prevButtons & mask == 0) {
      handler(button);
    }
  }

  void _repeatable(
    int buttons,
    int mask,
    GamepadButton button,
    GamepadHandler handler,
  ) {
    final down = buttons & mask != 0;
    final was = _prevButtons & mask != 0;
    if (down && !was) {
      handler(button);
      _held = mask;
      _repeatAt = DateTime.now().add(const Duration(milliseconds: 380));
      return;
    }
    if (!down && _held == mask) {
      _held = 0;
      _repeatAt = null;
      return;
    }
    if (down && _held == mask && _repeatAt != null) {
      final now = DateTime.now();
      if (now.isAfter(_repeatAt!)) {
        handler(button);
        _repeatAt = now.add(const Duration(milliseconds: 120));
      }
    }
  }
}

typedef XInputGetStateNative = Uint32 Function(
  Uint32 dwUserIndex,
  Pointer<XINPUT_STATE> pState,
);
typedef XInputGetStateDart = int Function(
  int dwUserIndex,
  Pointer<XINPUT_STATE> pState,
);

base class XINPUT_GAMEPAD extends Struct {
  @Uint16()
  external int wButtons;
  @Uint8()
  external int bLeftTrigger;
  @Uint8()
  external int bRightTrigger;
  @Int16()
  external int sThumbLX;
  @Int16()
  external int sThumbLY;
  @Int16()
  external int sThumbRX;
  @Int16()
  external int sThumbRY;
}

base class XINPUT_STATE extends Struct {
  @Uint32()
  external int dwPacketNumber;
  external XINPUT_GAMEPAD Gamepad;
}
