import 'dart:io';

import 'package:homedeck/core/library_controller.dart';
import 'package:homedeck/core/models/app_record.dart';
import 'package:homedeck/platform/windows_adapter.dart';

/// Honor `HOMEDECK_ADD_PATH` before the UI mounts so Ally diagnostics land
/// `apps[]` even when SendKeys `a` never opens a picker (see tip 82a5a20).
///
/// Returns the added (or existing matching) record, or `null` when the env
/// is unset / not a supported path. [pathOverride] is for tests; production
/// reads `Platform.environment['HOMEDECK_ADD_PATH']`. On non-Windows hosts
/// the env path is ignored unless [pathOverride] is passed.
Future<AppRecord?> seedHomeDeckAddPath(
  LibraryController controller, {
  String? pathOverride,
}) async {
  final path =
      (pathOverride ??
              (Platform.isWindows
                  ? Platform.environment['HOMEDECK_ADD_PATH']
                  : null))
          ?.trim() ??
      '';
  if (path.isEmpty) {
    return null;
  }
  for (final app in controller.apps) {
    for (final target in app.targets.values) {
      if (target.value == path) {
        return app;
      }
    }
  }
  final picked = WindowsAdapter.pickedLaunchFromPath(path);
  if (picked == null) {
    return null;
  }
  return controller.addRecord(
    displayName: picked.displayName,
    target: picked.target,
    kind: picked.kind,
    pinToHome: true,
  );
}
