/// Why a launch target could not be opened.
enum LaunchFailureKind {
  missingFile,
  permissionDenied,
  removedDrive,
  launchFailed;

  /// Living-room-readable copy, independent of OS error strings.
  String get headline => switch (this) {
    LaunchFailureKind.missingFile => 'This app was moved or is missing.',
    LaunchFailureKind.permissionDenied =>
      'Permission denied. HomeDeck cannot open this file.',
    LaunchFailureKind.removedDrive =>
      'The drive for this app was removed or is disconnected.',
    LaunchFailureKind.launchFailed => 'HomeDeck could not start this app.',
  };
}

sealed class LaunchOutcome {
  const LaunchOutcome();
}

final class LaunchSuccess extends LaunchOutcome {
  const LaunchSuccess();
}

final class LaunchFailure extends LaunchOutcome {
  const LaunchFailure({
    required this.kind,
    required this.message,
    this.detail,
    this.targetValue,
  });

  factory LaunchFailure.missingFile({String? targetValue, String? detail}) {
    return LaunchFailure(
      kind: LaunchFailureKind.missingFile,
      message: LaunchFailureKind.missingFile.headline,
      detail: detail,
      targetValue: targetValue,
    );
  }

  factory LaunchFailure.permissionDenied({String? targetValue, String? detail}) {
    return LaunchFailure(
      kind: LaunchFailureKind.permissionDenied,
      message: LaunchFailureKind.permissionDenied.headline,
      detail: detail,
      targetValue: targetValue,
    );
  }

  factory LaunchFailure.removedDrive({String? targetValue, String? detail}) {
    return LaunchFailure(
      kind: LaunchFailureKind.removedDrive,
      message: LaunchFailureKind.removedDrive.headline,
      detail: detail,
      targetValue: targetValue,
    );
  }

  factory LaunchFailure.launchFailed({String? targetValue, String? detail}) {
    return LaunchFailure(
      kind: LaunchFailureKind.launchFailed,
      message: LaunchFailureKind.launchFailed.headline,
      detail: detail,
      targetValue: targetValue,
    );
  }

  final LaunchFailureKind kind;
  final String message;
  final String? detail;
  final String? targetValue;

  @override
  bool operator ==(Object other) {
    return other is LaunchFailure &&
        other.kind == kind &&
        other.message == message &&
        other.detail == detail &&
        other.targetValue == targetValue;
  }

  @override
  int get hashCode => Object.hash(kind, message, detail, targetValue);
}
