import 'package:flutter/widgets.dart';

/// Navigation intents shared by keyboard, mouse, and (later) gamepad/touch.
class LaunchFocusedIntent extends Intent {
  const LaunchFocusedIntent();
}

class RemoveFocusedIntent extends Intent {
  const RemoveFocusedIntent();
}

class AddAppIntent extends Intent {
  const AddAppIntent();
}

class ToggleMoveModeIntent extends Intent {
  const ToggleMoveModeIntent();
}

class MoveTileIntent extends Intent {
  const MoveTileIntent(this.direction);

  final TraversalDirection direction;
}

class ToggleFullscreenIntent extends Intent {
  const ToggleFullscreenIntent();
}

class ToggleBorderlessIntent extends Intent {
  const ToggleBorderlessIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class DismissOverlayIntent extends Intent {
  const DismissOverlayIntent();
}

class ConfirmIntent extends Intent {
  const ConfirmIntent();
}

class ToggleFavoriteIntent extends Intent {
  const ToggleFavoriteIntent();
}

class NextTabIntent extends Intent {
  const NextTabIntent();
}

class PrevTabIntent extends Intent {
  const PrevTabIntent();
}

class OpenMenuIntent extends Intent {
  const OpenMenuIntent();
}

class OpenDetailsIntent extends Intent {
  const OpenDetailsIntent();
}

class ToggleLibraryGroupIntent extends Intent {
  const ToggleLibraryGroupIntent();
}

class OpenSearchIntent extends Intent {
  const OpenSearchIntent();
}

/// Steam library discover → import (Settings scan / Ally bare `S`).
class ScanSteamLibraryIntent extends Intent {
  const ScanSteamLibraryIntent();
}

/// Start Menu Programs discover → import (Settings scan / Ally bare `P`).
class ScanStartMenuIntent extends Intent {
  const ScanStartMenuIntent();
}

/// Pin the focused Library record onto Home (UI Add to Home / Ally bare `H`).
class PinFocusedToHomeIntent extends Intent {
  const PinFocusedToHomeIntent();
}
