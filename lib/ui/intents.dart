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

/// Open the RT-style Notifications panel (StatusCluster bell / Ally bare `T`).
class OpenNotificationsIntent extends Intent {
  const OpenNotificationsIntent();
}

/// Open the LT-style Friends panel (ProfileCluster / Ally bare `F`).
class OpenFriendsIntent extends Intent {
  const OpenFriendsIntent();
}

/// Steam library discover → import (Settings scan / Ally bare `S`).
class ScanSteamLibraryIntent extends Intent {
  const ScanSteamLibraryIntent();
}

/// Start Menu Programs discover → import (Settings scan / Ally bare `P`).
class ScanStartMenuIntent extends Intent {
  const ScanStartMenuIntent();
}

/// ROM-folder discover → import (Settings scan / Ally bare `R`).
class ScanRomFolderIntent extends Intent {
  const ScanRomFolderIntent();
}

/// Epic Games library discover → import (Settings scan / Ally bare `E`).
class ScanEpicLibraryIntent extends Intent {
  const ScanEpicLibraryIntent();
}

/// GOG Galaxy library discover → import (Settings scan / Ally bare `G`).
class ScanGogLibraryIntent extends Intent {
  const ScanGogLibraryIntent();
}

/// Ubisoft Connect library discover → import (Settings scan / Ally bare `U`).
class ScanUbisoftLibraryIntent extends Intent {
  const ScanUbisoftLibraryIntent();
}

/// EA App / Origin library discover → import (Settings scan / Ally bare `O`).
class ScanEaLibraryIntent extends Intent {
  const ScanEaLibraryIntent();
}

/// Battle.net library discover → import (Settings scan / Ally bare `N`).
class ScanBattlenetLibraryIntent extends Intent {
  const ScanBattlenetLibraryIntent();
}

/// Xbox / Microsoft Store library discover → import (Settings scan / Ally bare `W`).
class ScanXboxLibraryIntent extends Intent {
  const ScanXboxLibraryIntent();
}

/// Pin the focused Library record onto Home (UI Add to Home / Ally bare `H`).
class PinFocusedToHomeIntent extends Intent {
  const PinFocusedToHomeIntent();
}
