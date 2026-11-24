import 'dart:io';

import 'package:homedeck/core/device_status.dart';
import 'package:homedeck/core/gamepad.dart';
import 'package:homedeck/platform/windows_battery.dart';
import 'package:homedeck/platform/windows_xinput.dart';

GamepadSource selectGamepadSource() {
  if (Platform.isWindows) {
    return WindowsXInputGamepad();
  }
  return IdleGamepadSource();
}

DeviceStatus selectDeviceStatus() {
  if (Platform.isWindows) {
    return WindowsBatteryStatus();
  }
  return MemoryDeviceStatus();
}
