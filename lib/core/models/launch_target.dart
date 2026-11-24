import 'package:homedeck/core/models/app_platform.dart';

/// How a platform identifies something HomeDeck can launch.
///
/// Values are native to one device. Do not reuse a Windows path as a macOS
/// bundle id, an Android package name, or a Linux desktop-file id.
enum LaunchTargetKind {
  windowsExecutable,
  windowsShortcut,
  macosBundleId,
  androidPackage,
  linuxDesktopEntry;

  String get wireName => name;

  static LaunchTargetKind fromWire(String value) {
    for (final kind in LaunchTargetKind.values) {
      if (kind.name == value) {
        return kind;
      }
    }
    throw FormatException('Unknown LaunchTargetKind: $value');
  }
}

/// A platform-native launch descriptor for one app on one OS.
class LaunchTarget {
  const LaunchTarget({
    required this.platform,
    required this.kind,
    required this.value,
    this.arguments = const [],
  });

  final AppPlatform platform;
  final LaunchTargetKind kind;

  /// Opaque native identifier: an absolute Windows path, a macOS bundle id,
  /// an Android package name, or a Linux launch target. Not a HomeDeck id.
  final String value;

  final List<String> arguments;

  Map<String, Object?> toJson() => {
    'platform': platform.wireName,
    'kind': kind.wireName,
    'value': value,
    'arguments': arguments,
  };

  factory LaunchTarget.fromJson(Map<String, Object?> json) {
    final arguments = json['arguments'];
    return LaunchTarget(
      platform: AppPlatform.fromWire(json['platform'] as String),
      kind: LaunchTargetKind.fromWire(json['kind'] as String),
      value: json['value'] as String,
      arguments: arguments is List
          ? arguments.map((entry) => '$entry').toList(growable: false)
          : const [],
    );
  }

  LaunchTarget copyWith({
    AppPlatform? platform,
    LaunchTargetKind? kind,
    String? value,
    List<String>? arguments,
  }) {
    return LaunchTarget(
      platform: platform ?? this.platform,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      arguments: arguments ?? this.arguments,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LaunchTarget &&
        other.platform == platform &&
        other.kind == kind &&
        other.value == value &&
        _listEquals(other.arguments, arguments);
  }

  @override
  int get hashCode => Object.hash(platform, kind, value, Object.hashAll(arguments));
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
