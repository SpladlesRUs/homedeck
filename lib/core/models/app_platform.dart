/// Operating systems HomeDeck can store a launch target for.
///
/// An [AppRecord] may include only a subset of these. A Windows-only record is
/// valid; identifiers are never treated as portable across devices.
enum AppPlatform {
  windows,
  macos,
  android,
  linux;

  String get wireName => name;

  static AppPlatform fromWire(String value) {
    for (final platform in AppPlatform.values) {
      if (platform.name == value) {
        return platform;
      }
    }
    throw FormatException('Unknown AppPlatform: $value');
  }
}
