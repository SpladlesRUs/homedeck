// ignore_for_file: camel_case_types, non_constant_identifier_names

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:homedeck/core/device_status.dart';

/// Reads [GetSystemPowerStatus]. Hides the meter when there is no battery.
class WindowsBatteryStatus implements DeviceStatus {
  WindowsBatteryStatus();

  int? _percent;
  Timer? _timer;
  void Function()? _onChange;
  GetSystemPowerStatusDart? _getStatus;
  bool _bindFailed = false;

  @override
  int? get batteryPercent => _percent;

  @override
  void start(void Function() onChange) {
    _onChange = onChange;
    if (!Platform.isWindows) {
      return;
    }
    _bind();
    _refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _onChange = null;
  }

  void _bind() {
    if (_getStatus != null || _bindFailed) {
      return;
    }
    try {
      final lib = DynamicLibrary.open('kernel32.dll');
      _getStatus = lib
          .lookup<NativeFunction<GetSystemPowerStatusNative>>(
            'GetSystemPowerStatus',
          )
          .asFunction();
    } catch (_) {
      _bindFailed = true;
    }
  }

  void _refresh() {
    final getStatus = _getStatus;
    if (getStatus == null) {
      return;
    }
    final status = calloc<SYSTEM_POWER_STATUS>();
    try {
      if (getStatus(status) == 0) {
        return;
      }
      final flag = status.ref.BatteryFlag;
      final raw = status.ref.BatteryLifePercent;
      int? next;
      if (flag & 128 == 0 && raw <= 100) {
        next = raw;
      }
      if (next != _percent) {
        _percent = next;
        _onChange?.call();
      }
    } catch (_) {
      _percent = null;
    } finally {
      calloc.free(status);
    }
  }
}

typedef GetSystemPowerStatusNative = Int32 Function(
  Pointer<SYSTEM_POWER_STATUS> status,
);
typedef GetSystemPowerStatusDart = int Function(
  Pointer<SYSTEM_POWER_STATUS> status,
);

base class SYSTEM_POWER_STATUS extends Struct {
  @Uint8()
  external int ACLineStatus;
  @Uint8()
  external int BatteryFlag;
  @Uint8()
  external int BatteryLifePercent;
  @Uint8()
  external int SystemStatusFlag;
  @Uint32()
  external int BatteryLifeTime;
  @Uint32()
  external int BatteryFullLifeTime;
}
