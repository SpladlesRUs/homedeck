#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  win32_.Register(flutter_controller_->engine()->messenger(), this);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Ally Phase2 primarily uses WScript.SendKeys (Flutter view child), which
  // the WH_KEYBOARD_LL hook in HomedeckWin32 handles. Keep this top-level
  // path for PostMessage / real keyboard focus on the frame window.
  if (message == WM_HOMEDECK_ADD) {
    win32_.HandleAddKey();
    return 0;
  }
  if (message == WM_HOMEDECK_SCAN_STEAM) {
    win32_.HandleScanSteamKey();
    return 0;
  }
  if (message == WM_HOMEDECK_SCAN_START_MENU) {
    win32_.HandleScanStartMenuKey();
    return 0;
  }
  if (message == WM_HOMEDECK_SCAN_ROMS) {
    win32_.HandleScanRomsKey();
    return 0;
  }
  if (message == WM_HOMEDECK_SCAN_EPIC) {
    win32_.HandleScanEpicKey();
    return 0;
  }
  if (message == WM_HOMEDECK_SCAN_GOG) {
    win32_.HandleScanGogKey();
    return 0;
  }
  if (message == WM_HOMEDECK_SCAN_UBISOFT) {
    win32_.HandleScanUbisoftKey();
    return 0;
  }
  if (message == WM_HOMEDECK_PIN_HOME) {
    win32_.HandlePinHomeKey();
    return 0;
  }
  if (message == WM_HOMEDECK_REMOVE) {
    win32_.HandleRemoveKey();
    return 0;
  }
  if (message == WM_HOMEDECK_CONFIRM) {
    win32_.HandleConfirmKey();
    return 0;
  }
  if (message == WM_HOMEDECK_GAME_EXIT) {
    const uint64_t generation =
        (static_cast<uint64_t>(static_cast<uint32_t>(lparam)) << 32) |
        static_cast<uint32_t>(wparam);
    win32_.HandleGameExit(generation);
    return 0;
  }
  // Ally Phase2: F11 posted to the top-level HWND never changed chrome when
  // Dart only used FindWindow / window_manager. Toggle via the real HWND and
  // let Dart sync badge/prefs over the method channel event.
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) &&
      wparam == VK_F11) {
    win32_.SetFullscreen(!win32_.IsFullscreen());
    return 0;
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) &&
      wparam == VK_RETURN) {
    if (win32_.HandleEnter()) {
      return 0;
    }
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && wparam == 'A') {
    const bool mods = (GetKeyState(VK_CONTROL) & 0x8000) != 0 ||
                      (GetKeyState(VK_MENU) & 0x8000) != 0 ||
                      (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
                      (GetKeyState(VK_RWIN) & 0x8000) != 0;
    if (!mods) {
      win32_.HandleAddKey();
      return 0;
    }
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && wparam == 'S') {
    const bool mods = (GetKeyState(VK_CONTROL) & 0x8000) != 0 ||
                      (GetKeyState(VK_MENU) & 0x8000) != 0 ||
                      (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
                      (GetKeyState(VK_RWIN) & 0x8000) != 0;
    if (!mods) {
      win32_.HandleScanSteamKey();
      return 0;
    }
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && wparam == 'R') {
    const bool mods = (GetKeyState(VK_CONTROL) & 0x8000) != 0 ||
                      (GetKeyState(VK_MENU) & 0x8000) != 0 ||
                      (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
                      (GetKeyState(VK_RWIN) & 0x8000) != 0;
    if (!mods) {
      win32_.HandleScanRomsKey();
      return 0;
    }
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && wparam == 'E') {
    const bool mods = (GetKeyState(VK_CONTROL) & 0x8000) != 0 ||
                      (GetKeyState(VK_MENU) & 0x8000) != 0 ||
                      (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
                      (GetKeyState(VK_RWIN) & 0x8000) != 0;
    if (!mods) {
      win32_.HandleScanEpicKey();
      return 0;
    }
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && wparam == 'G') {
    const bool mods = (GetKeyState(VK_CONTROL) & 0x8000) != 0 ||
                      (GetKeyState(VK_MENU) & 0x8000) != 0 ||
                      (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
                      (GetKeyState(VK_RWIN) & 0x8000) != 0;
    if (!mods) {
      win32_.HandleScanGogKey();
      return 0;
    }
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && wparam == 'U') {
    const bool mods = (GetKeyState(VK_CONTROL) & 0x8000) != 0 ||
                      (GetKeyState(VK_MENU) & 0x8000) != 0 ||
                      (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
                      (GetKeyState(VK_RWIN) & 0x8000) != 0;
    if (!mods) {
      win32_.HandleScanUbisoftKey();
      return 0;
    }
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) && wparam == 'H') {
    const bool mods = (GetKeyState(VK_CONTROL) & 0x8000) != 0 ||
                      (GetKeyState(VK_MENU) & 0x8000) != 0 ||
                      (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
                      (GetKeyState(VK_RWIN) & 0x8000) != 0;
    if (!mods) {
      win32_.HandlePinHomeKey();
      return 0;
    }
  }
  if ((message == WM_KEYDOWN || message == WM_SYSKEYDOWN) &&
      (wparam == VK_DELETE || wparam == VK_BACK)) {
    const bool mods = (GetKeyState(VK_CONTROL) & 0x8000) != 0 ||
                      (GetKeyState(VK_MENU) & 0x8000) != 0 ||
                      (GetKeyState(VK_LWIN) & 0x8000) != 0 ||
                      (GetKeyState(VK_RWIN) & 0x8000) != 0;
    if (!mods) {
      win32_.SetRemoveArmed(true);
      win32_.SetFocusedLaunch(L"", L"");
      win32_.HandleRemoveKey();
      return 0;
    }
  }

  // Background extractIcon worker finished — complete the MethodChannel on
  // the platform thread (must not call MethodResult from the worker).
  if (message == WM_HOMEDECK_ICON_DONE) {
    win32_.HandleIconDone(lparam);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  // Forward unhandled key messages to the Flutter view when the top-level
  // window received them (Ally harness PostMessage) but focus is elsewhere.
  if (message == WM_KEYDOWN || message == WM_KEYUP ||
      message == WM_SYSKEYDOWN || message == WM_SYSKEYUP ||
      message == WM_CHAR || message == WM_SYSCHAR) {
    HWND child = flutter_controller_ && flutter_controller_->view()
                     ? flutter_controller_->view()->GetNativeWindow()
                     : nullptr;
    if (child != nullptr && GetFocus() != child) {
      return SendMessage(child, message, wparam, lparam);
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
