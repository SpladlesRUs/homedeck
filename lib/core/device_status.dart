/// Battery and other host chrome. Null percent means "hide the meter".
abstract class DeviceStatus {
  int? get batteryPercent;

  void start(void Function() onChange);

  void stop();
}

class MemoryDeviceStatus implements DeviceStatus {
  MemoryDeviceStatus({this.batteryPercent});

  @override
  int? batteryPercent;

  void Function()? _onChange;

  @override
  void start(void Function() onChange) {
    _onChange = onChange;
  }

  @override
  void stop() {
    _onChange = null;
  }

  void setBatteryPercent(int? value) {
    batteryPercent = value;
    _onChange?.call();
  }
}
