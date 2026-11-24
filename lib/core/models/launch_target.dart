import 'package:homedeck/core/models/app_platform.dart';

/// How a platform identifies something HomeDeck can launch.
///
/// Values are native to one device. Do not reuse a Windows path as a macOS
/// bundle id, an Android package name, or a Linux desktop-file id.
enum LaunchTargetKind {
  windowsExecutable,
  windowsShortcut,
  windowsUri,
  windowsEmulated,
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
    this.romPath,
    this.argsTemplate,
  });

  final AppPlatform platform;
  final LaunchTargetKind kind;

  /// Opaque native identifier: an absolute Windows path, a store URI
  /// (`steam://rungameid/…`), a macOS bundle id, an Android package name, or
  /// a Linux launch target. For emulated tiles this is the emulator `.exe`.
  final String value;

  final List<String> arguments;

  /// ROM / disc image for [LaunchTargetKind.windowsEmulated].
  final String? romPath;

  /// Argument template for emulated launches. `{rom}` is replaced with
  /// [romPath]. Empty means `{rom}` alone.
  final String? argsTemplate;

  bool get isUri => kind == LaunchTargetKind.windowsUri;

  bool get isEmulated => kind == LaunchTargetKind.windowsEmulated;

  /// Arguments actually passed to the process.
  List<String> get resolvedArguments {
    if (!isEmulated) {
      return arguments;
    }
    return expandLaunchArgs(
      template: argsTemplate,
      romPath: romPath ?? '',
    );
  }

  Map<String, Object?> toJson() => {
    'platform': platform.wireName,
    'kind': kind.wireName,
    'value': value,
    'arguments': arguments,
    if (romPath != null) 'romPath': romPath,
    if (argsTemplate != null) 'argsTemplate': argsTemplate,
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
      romPath: json['romPath'] as String?,
      argsTemplate: json['argsTemplate'] as String?,
    );
  }

  LaunchTarget copyWith({
    AppPlatform? platform,
    LaunchTargetKind? kind,
    String? value,
    List<String>? arguments,
    String? romPath,
    bool clearRomPath = false,
    String? argsTemplate,
    bool clearArgsTemplate = false,
  }) {
    return LaunchTarget(
      platform: platform ?? this.platform,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      arguments: arguments ?? this.arguments,
      romPath: clearRomPath ? null : (romPath ?? this.romPath),
      argsTemplate: clearArgsTemplate
          ? null
          : (argsTemplate ?? this.argsTemplate),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LaunchTarget &&
        other.platform == platform &&
        other.kind == kind &&
        other.value == value &&
        _listEquals(other.arguments, arguments) &&
        other.romPath == romPath &&
        other.argsTemplate == argsTemplate;
  }

  @override
  int get hashCode => Object.hash(
    platform,
    kind,
    value,
    Object.hashAll(arguments),
    romPath,
    argsTemplate,
  );
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

/// Split [template] on whitespace (honoring double quotes) and substitute
/// `{rom}` with [romPath]. An empty template is `{rom}`.
List<String> expandLaunchArgs({
  required String romPath,
  String? template,
}) {
  final raw = (template == null || template.trim().isEmpty)
      ? '{rom}'
      : template.trim();
  return tokenizeLaunchArgs(raw)
      .map((token) => token.replaceAll('{rom}', romPath))
      .toList(growable: false);
}

List<String> tokenizeLaunchArgs(String input) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuote = false;
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    if (ch == '"') {
      inQuote = !inQuote;
      continue;
    }
    if (!inQuote && (ch == ' ' || ch == '\t')) {
      if (buf.isNotEmpty) {
        out.add(buf.toString());
        buf.clear();
      }
      continue;
    }
    buf.write(ch);
  }
  if (buf.isNotEmpty) {
    out.add(buf.toString());
  }
  return out;
}
