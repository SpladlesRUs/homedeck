import 'package:homedeck/platform/platform_adapter.dart';
import 'package:homedeck/platform/windows_adapter.dart';
import 'package:homedeck/platform/windows_io.dart';

/// Chooses the adapter for this process.
///
/// Milestone 1 always returns [WindowsAdapter]. macOS, Android, and
/// Linux/Steam Deck adapters should be added here later — see
/// docs/ARCHITECTURE.md. The Linux desktop target exists only so the shared
/// UI can run in a VM; it does not implement Linux launch behavior.
PlatformAdapter selectPlatformAdapter({
  WindowsIo io = const DartWindowsIo(),
  FilePickerFn? filePicker,
}) {
  return WindowsAdapter(io: io, filePicker: filePicker);
}
